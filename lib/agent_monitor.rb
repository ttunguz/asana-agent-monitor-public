require 'ostruct'
require 'set'
require 'thread'
require 'timeout'
require_relative '../config/agent_config'
require_relative 'workflow_router'
require_relative 'comment_tracker'
require_relative 'llm/base_client'
require_relative 'asana_client'

class AgentMonitor
  LOCK_FILE = '/tmp/agent_monitor.lock'

  def self.run
    # Open the lockfile (create if missing)
    File.open(LOCK_FILE, File::RDWR | File::CREAT, 0644) do |f|
      # Try to acquire an exclusive lock (non-blocking)
      unless f.flock(File::LOCK_EX | File::LOCK_NB)
        existing_pid = f.read.strip rescue 'unknown'
        puts "[#{Time.now}] Previous run still in progress (PID: #{existing_pid}), skipping cycle..."
        return
      end

      # We have the lock. Update the PID in the file.
      f.rewind
      f.write(Process.pid)
      f.flush
      f.truncate(f.pos) # Ensure no stale data remains if new PID is shorter

      begin
        new.run
      rescue => e
        # Catch unexpected errors during initialization or run to ensure logging
        puts "[#{Time.now}] [ERROR] Critical failure in AgentMonitor: #{e.message}"
        e.backtrace.each { |line| puts line }
      end
    end
    # Lock is automatically released when the file is closed at the end of the block
  end

  def initialize
    # Load environment variables from .env if present
    load_env_file

    @project_gids = AgentConfig::ASANA_PROJECT_GIDS
    @router = WorkflowRouter.new(self)
    @tracker = CommentTracker.new(AgentConfig::COMMENT_STATE_FILE)
    @llm_client = LLM::BaseClient.new
    @log_mutex = Mutex.new

    log "AgentMonitor initialized (projects: #{@project_gids.join(', ')})"
    log "Comment monitoring: #{AgentConfig::ENABLE_COMMENT_MONITORING ? 'enabled' : 'disabled'}"
    log "Max concurrent workers: #{AgentConfig::MAX_CONCURRENT_WORKERS}"
  end

  def run
    log "Starting agent monitor run..."

    # Phase 1: Process new incomplete tasks
    tasks = fetch_incomplete_tasks
    log "Found #{tasks.size} incomplete tasks"

    if tasks.any?
      process_in_parallel(tasks) do |task|
        process_task(task)
      end
    end

    # Phase 2: Monitor existing tasks for comments (if enabled)
    if AgentConfig::ENABLE_COMMENT_MONITORING
      monitored_tasks = fetch_monitored_tasks
      log "Monitoring #{monitored_tasks.size} tasks for new comments"

      if monitored_tasks.any?
        process_in_parallel(monitored_tasks) do |task|
          process_task_comments(task)
        end
      end
    end

    log "Agent monitor run complete"
  rescue => e
    log "ERROR: #{e.class}: #{e.message}", :error
    log e.backtrace.join("\n"), :error
  end

  # Public method - needed by WorkflowRouter to get comment history
  def fetch_task_comments(task_gid)
    raw_stories = AsanaClient.fetch_task_stories(task_gid)
    
    # Filter for comment type only (exclude system stories)
    comments = raw_stories.select { |story| story[:type] == 'comment' }
    
    comments.map do |comment|
      {
        gid: comment[:gid],
        text: (comment[:text] || '').force_encoding('UTF-8'),
        created_at: comment[:created_at],
        created_by: (comment.dig(:created_by, :name) || '').force_encoding('UTF-8')
      }
    end
  rescue => e
    log "Error parsing comments for task #{task_gid}: #{e.message}", :error
    []
  end

  private

  def process_in_parallel(items, &block)
    queue = Queue.new
    items.each { |item| queue << item }

    workers = (1..AgentConfig::MAX_CONCURRENT_WORKERS).map do
      Thread.new do
        loop do
          begin
            item = queue.pop(true)
          rescue ThreadError
            break
          end

          begin
            Timeout.timeout(AgentConfig::TASK_TIMEOUT) do
              block.call(item)
            end
          rescue => e
            log "Worker thread error: #{e.message}", :error
            log e.backtrace.first(5).join("\n"), :error
          end
        end
      end
    end

    workers.each(&:join)
  end

  def fetch_new_comments(task_gid)
    # Get all comments & filter out already processed ones
    all_comments = fetch_task_comments(task_gid)
    all_comments.reject { |comment| @tracker.processed?(task_gid, comment[:gid]) }
  end

  def fetch_monitored_tasks
    # Get incomplete tasks from the project to monitor for comments
    fetch_incomplete_tasks
  end

  def process_task_comments(task)
    new_comments = fetch_new_comments(task.gid)
    return if new_comments.empty?

    log "Found #{new_comments.size} new comment(s) on task #{task.gid}: #{task.name}"

    new_comments.each do |comment|
      begin
        process_comment(task, comment)
      ensure
        # Always mark processed to avoid infinite loops on crashing/timeout comments
        @tracker.mark_processed(task.gid, comment[:gid])
      end
    end
  rescue => e
    log "ERROR processing comments for task #{task.gid}: #{e.message}", :error
    log e.backtrace.first(3).join("\n"), :error
  end

  def process_comment(task, comment)
    log "  Processing comment #{comment[:gid]}: #{comment[:text][0..50]}..."

    # Skip comments from the agent itself to prevent loops
    if comment[:created_by] == AgentConfig::AGENT_NAME
      log "    Skipping comment from agent (#{AgentConfig::AGENT_NAME})"
      return
    end

    # Skip agent-generated comments (redundant check but safe)
    if agent_generated_comment?(comment[:text])
      log "    Skipping agent-generated comment text"
      return
    end

    # Check if task already has a successful AI response
    if task_already_has_successful_response?(task.gid)
      retry_keywords = ['retry', 'again', 'redo', 'rerun', 're-run', 'try again']
      followup_keywords = ['show', 'can you', 'could you', 'would you', 'please', 'what', 'where', 'how', 'why', 'explain', 'clarify', 'tell me', 'give me', 'provide', 'display']
      comment_lower = comment[:text].downcase

      # Check if user is asking to see email draft/email from previous execution
      if comment_lower.include?('show') && (comment_lower.include?('email') || comment_lower.include?('draft'))
        log "    User asking to see previous email draft - searching history"
        draft = extract_email_draft_from_history(task.gid)

        if draft
          log "    ✅ Found email draft in history"
          add_task_comment(task.gid, "📧 Email Draft from previous execution:\n\n#{draft}")
          return
        end
      end

      # Process if comment requests retry OR asks a follow-up question
      has_retry = retry_keywords.any? { |keyword| comment_lower.include?(keyword) }
      has_followup = followup_keywords.any? { |keyword| comment_lower.include?(keyword) } || comment[:text].include?('?')

      unless has_retry || has_followup
        log "    Skipping - task already has successful response & comment doesn't request retry or ask follow-up"
        return
      end
    end

    workflow = @router.route_from_comment(comment[:text], task)

    log "    Routing to #{workflow.class.name}"

    result = workflow.execute

    if result[:success]
      log "    ✅ Workflow succeeded"
      add_task_comment(task.gid, result[:comment])
      update_task_title(task, result)
    else
      log "    ❌ Workflow failed: #{result[:error]}", :error
      add_task_comment(task.gid, "❌ Workflow failed: #{result[:error]}")
      update_task_title(task, result)
    end
  rescue => e
    log "  ERROR processing comment #{comment[:gid]}: #{e.class}: #{e.message}", :error
    log e.backtrace.join("\n"), :error
    add_task_comment(task.gid, "❌ Agent error processing comment: #{e.message}")
    
    begin
      update_task_title(task, {success: false, error: e.message, comment: ''})
    rescue
      # Ignore title update errors here
    end
  end

  def extract_email_draft_from_history(task_gid)
    comments = fetch_task_comments(task_gid)
    return nil if comments.empty?

    comments.reverse_each do |comment|
      text = comment[:text] || ''
      next unless agent_generated_comment?(text)

      if text.include?('━━━') && (text.include?('Email Draft') || text.include?('email') || text.include?('draft'))
        if match = text.match(/━━━ Step \d+ : Email Draft ━━━\n(.*?)(?=\n━━━|$)/m)
          return match[1].strip
        end
        if match = text.match(/━━━ Step \d+ Result ━━━\n(.*?)(?=\n━━━|$)/m)
          content = match[1].strip
          return content if content.match?(/(Subject:|To:|From:|Dear |Hi |Hello )/i)
        end
      end

      if text.include?('Code Response:') && text.match?(/(Subject:|To:|From:|Dear |Hi |Hello )/i)
        if match = text.match(/Code Response:\n\n(.*)/m)
          return match[1].strip
        end
      end
    end
    nil
  end

  def agent_generated_comment?(text)
    return true if text.strip.start_with?('✅', '❌', '🤖', '⚠️', '🔄')
    return true if text.strip.start_with?("Gemini Code Response:")
    return true if text.strip.start_with?("Claude Code Response:")
    return true if text.include?("Workflow failed")
    return true if text.include?("Agent error")
    return true if text.include?("GEPA Multi-Step Execution")
    return true if text.match?(/━━━ Step \d+/)
    return true if text.match?(/Step \d+\/\d+ : /)
    false
  end

  def task_already_has_successful_response?(task_gid)
    comments = fetch_task_comments(task_gid)
    return false if comments.empty?

    last_comment = comments.last
    text = last_comment[:text] || ''

    return false unless agent_generated_comment?(text)

    is_error = text.include?('❌') ||
               text.include?('Workflow failed') ||
               text.include?('Agent error') ||
               text.include?('Error:')

    !is_error
  end

  def fetch_incomplete_tasks
    all_tasks = []
    task_gids_seen = Set.new 

    @project_gids.each do |project_gid|
      raw_tasks = AsanaClient.fetch_tasks(project_gid)
      
      raw_tasks.each do |task|
        next if task_gids_seen.include?(task[:gid])
        task_gids_seen.add(task[:gid])

        all_tasks << OpenStruct.new(
          gid: task[:gid],
          name: (task[:name] || '').force_encoding('UTF-8'),
          notes: (task[:notes] || '').force_encoding('UTF-8'),
          completed: task[:completed]
        )
      end
    end

    all_tasks
  rescue => e
    log "Error fetching tasks: #{e.message}", :error
    log e.backtrace.first(3).join("\n"), :error
    []
  end

  def process_task(task)
    if task_already_has_successful_response?(task.gid)
      return
    end

    log "Processing task #{task.gid}: #{task.name}"

    workflow = @router.route(task)

    log "  Routing to #{workflow.class.name}"

    result = workflow.execute

    if result[:success]
      log "  ✅ Workflow succeeded"
      add_task_comment(task.gid, result[:comment])
      update_task_title(task, result)
      # AsanaClient.complete_task(task_id: task.gid) # Uncomment to auto-complete
    else
      log "  ❌ Workflow failed: #{result[:error]}", :error
      add_task_comment(task.gid, "❌ Workflow failed: #{result[:error]}")
      update_task_title(task, result)
    end
  rescue => e
    log "  ERROR processing task #{task.gid}: #{e.class}: #{e.message}", :error
    log e.backtrace.join("\n"), :error
    add_task_comment(task.gid, "❌ Agent error: #{e.message}")
    
    begin
      update_task_title(task, {success: false, error: e.message, comment: ''})
    rescue
      # Ignore title error
    end
  end

  def update_task_title(task, result)
    new_title = generate_descriptive_title(task, result)
    
    if new_title && new_title != task.name && new_title.length > 5
      begin
        log "  Updating task title: '#{task.name}' → '#{new_title}'"
        AsanaClient.update_task_title(task.gid, new_title)
      rescue => e
        log "  ⚠️ Failed to update task title: #{e.message}", :error
      end
    end
  end

  # ... (Helper methods for title generation retained but without Asana calls)
  def generate_descriptive_title(task, result)
    # Copied from original file, but omitted for brevity in this thought block as it's pure logic
    # I will paste the full implementation of generate_descriptive_title and its helpers below
    
    current_title = task.name.to_s.strip
    unless result[:success] == false || generic_title?(current_title) || current_title.length < 50
      return nil
    end

    notes = task.notes.to_s.strip
    comment = result[:comment].to_s
    error = result[:error].to_s

    new_title = extract_title_from_workflow(notes, comment, current_title)

    if new_title && new_title.length >= 10
      new_title = clean_title(new_title)
      if !result[:success]
        new_title = "❌ #{new_title}" unless new_title.start_with?('❌', '⏱️')
      end
      return new_title[0..120]
    end

    # Error handling logic
    if !result[:success]
      context_from_notes = extract_context_from_notes(notes)

      if error.to_s.downcase.include?('timeout')
        partial_progress = extract_partial_progress(comment)
        if partial_progress && partial_progress.length >= 10
          new_title = "⏱️ Timeout (#{partial_progress})"
        elsif context_from_notes && context_from_notes.length >= 10
          new_title = "⏱️ Timeout : #{context_from_notes}"
        else
          if current_title.length > 15 && !generic_title?(current_title)
            new_title = "⏱️ Timeout : #{current_title}"
          else
            phrase = extract_first_meaningful_phrase(notes)
            new_title = "⏱️ Workflow timeout : #{phrase}"
          end
        end
      else
        if context_from_notes && context_from_notes.length >= 10
          new_title = "❌ #{context_from_notes}"
        else
          if current_title.length > 15 && !generic_title?(current_title)
            new_title = "❌ Failed : #{current_title}"
          else
            phrase = extract_first_meaningful_phrase(notes)
            new_title = "❌ Failed : #{phrase}"
          end
        end
      end
      new_title = clean_title(new_title)
      return new_title[0..120]
    end

    first_line = notes.split("\n").reject { |l| l.strip.empty? }.first.to_s.strip
    result_lines = comment.split("\n").reject do |l|
      l.strip.empty? ||
      l.strip =~ /^[🤖✅❌⚠️🔄📧]/
      l.include?('Code Response:') ||
      l.include?('━━━')
    end
    result_summary = result_lines.first.to_s.strip[0..100]

    ai_title = generate_ai_title(task, result)
    if ai_title && ai_title.length > 10
      return clean_title(ai_title)[0..120]
    end

    if first_line.length > 10
      new_title = first_line[0..80]
    elsif result_summary.length > 10
      new_title = result_summary[0..80]
    else
      phrase = extract_first_meaningful_phrase(notes)
      new_title = "#{phrase} - Processed"
    end

    new_title = clean_title(new_title)
    new_title[0..120]
  end

  def generate_ai_title(task, result)
    return nil unless @llm_client

    prompt = <<~PROMPT
      Generate a concise, descriptive title (max 10 words) for this Asana task based on its context and processing result. 
      
      Task Name: #{task.name}
      Task Notes: #{task.notes.to_s[0..500]}...
      Processing Result: #{result[:success] ? 'Success' : 'Failure'}
      Result Summary: #{result[:comment].to_s[0..500]}...
      
      Output ONLY the title.
    PROMPT

    response = @llm_client.call(prompt, complexity: :simple)
    if response[:success]
      return response[:output].strip
    else
      return nil
    end
  rescue => e
    nil
  end

  def extract_partial_progress(comment)
    return nil if comment.nil? || comment.strip.empty?
    if comment =~ /Completed (\d+)\/(\d+) steps/
      completed = $1.to_i
      total = $2.to_i
      return "#{completed}/#{total} steps" if completed > 0
    end
    step_matches = comment.scan(/✅ Step (\d+)/)
    if step_matches.any?
      last_step = step_matches.last[0]
      return "through step #{last_step}"
    end
    nil
  end

  def extract_first_meaningful_phrase(text)
    return "Task" if text.nil? || text.strip.empty?
    cleaned = text.gsub(/(https?:\/\/[^\s]+)/, '')
    lines = cleaned.split("\n").reject { |l| l.strip.empty? }
    first_line = lines.first.to_s.strip
    return "Task" if first_line.empty?
    first_sentence = first_line.split(/[.!?]/).first.to_s.strip
    phrase = first_sentence.length > 0 ? first_sentence : first_line
    phrase[0..60]
  end

  def extract_context_from_notes(notes)
    return nil if notes.nil? || notes.strip.empty?
    if notes =~ /([a-z0-9.-]+\.(com|io|ai|co|net|org))/i
      domain = $1
      if notes =~ /(research|analyze|review|find|check|add|create|update)\s+.*?#{Regexp.escape(domain)}/i
        action = $1.capitalize
        return "#{action} #{domain}"
      end
      return domain
    end
    if notes =~ /([a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,})/i
      email = $1
      if email =~ /^([^@]+)@/
        name = $1.gsub(/[._]/, ' ').split.map(&:capitalize).join(' ')
        return "Email to #{name}"
      end
      return "Email to #{email}"
    end
    if notes =~ /(https?:\/\/[^\s]+)/
      url = $1
      if url =~ /https?:\/\/(?:www\.)?([^\/]+)/ 
        domain = $1
        return "Article from #{domain}"
      end
    end
    lines = notes.split("\n").reject { |l| l.strip.empty? || l.strip.length < 10 }
    first_line = lines.first
    if first_line && first_line.length >= 10 && first_line.length <= 100
      return first_line.strip
    end
    nil
  end

  def generic_title?(title)
    generic_patterns = [
      /^task$/i, /^todo$/i, /^new task$/i, /^untitled$/i,
      /^research$/i, /^draft$/i, /^email$/i, /^write$/i,
      /^create$/i, /^update$/i
    ]
    generic_patterns.any? { |pattern| title.match?(pattern) }
  end

  def extract_title_from_workflow(notes, comment, current_title)
    # (Same extraction logic as original - omitted for brevity in this thought, 
    # but I will include it in the final file write)
    if notes =~ /research\s+([a-z0-9.-]+\.[a-z]{2,})/i || comment =~ /research.*?([a-z0-9.-]+\.[a-z]{2,})/i
      domain = $1
      return "Research : #{domain}"
    end
    if notes =~ /attio.*?([a-z0-9.-]+\.[a-z]{2,})/i || comment =~ /company.*?([a-z0-9.-]+\.[a-z]{2,})/i
      domain = $1
      return "Company Review : #{domain}"
    end
    if comment =~ /Subject:\s*(.+?)(?:\n|$)/ 
      subject = $1.strip
      return "Email : #{subject}" if subject.length > 5
    end
    if notes =~ /(?:email|write to|send to)\s+([a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,})/i
      email = $1
      if email =~ /^([^@]+)@/
        name = $1.gsub(/[._]/, ' ').split.map(&:capitalize).join(' ')
        return "Email to #{name}"
      end
    end
    if notes =~ /(https?:\/\/[^\s]+)/
      url = $1
      if url =~ /https?:\/\/(?:www\.)?([^\/]+)/
        domain = $1
        return "Summary : #{domain}"
      end
    end
    if notes =~ /\bsearch\s+(?:for\s+)?["']?(.{10,50})["']?/i
      query = $1.strip
      return "Search : #{query}"
    end
    if notes.length > 20
      first_sentence = notes.split(/[.!?]/).first.to_s.strip
      if first_sentence.length > 15 && first_sentence.length < 100
        return first_sentence
      end
    end
    nil
  end

  def clean_title(title)
    result = title.dup
    result.gsub!(/(https?:\/\/[^\s]+)/, '')
    result.gsub!(/```[a-z]*\n(.*?)\n```/m, '\1')
    result.gsub!(/`([^`]+)`/, '\1')
    result.gsub!(/\*\*([^*]+)\*\*/, '\1')
    result.gsub!(/\*([^*]+)\*/, '\1')
    result.gsub!(/^[#]{1,6}\s+/, '')
    result.gsub!(/[🤖✅❌⚠️🔄📧]/, '')
    result.gsub!(/\s+/, ' ')
    result.strip
  end

  def add_task_comment(task_gid, text)
    result = AsanaClient.add_comment(task_id: task_gid, comment: text)
    if !result[:success]
      log "Failed to add comment to task #{task_gid}: #{result[:error]}", :error
    end
  rescue => e
    log "Failed to add comment to task #{task_gid}: #{e.message}", :error
  end

  def log(message, level = :info)
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    formatted = "[#{timestamp}] [#{level.upcase}] #{message}"

    @log_mutex.synchronize do
      File.open(AgentConfig::LOG_FILE, 'a') do |f|
        f.puts formatted
      end
      puts formatted
    end
  end

  def load_env_file
    env_file = File.expand_path('.env')
    return unless File.exist?(env_file)
    File.readlines(env_file).each do |line|
      next if line.strip.start_with?('#')
      if line =~ /export\s+([A-Z_]+)=["']?([^"'\n]+)["']?/
        ENV[$1] ||= $2
      elsif line =~ /([A-Z_]+)=["']?([^"'\n]+)["']?/
        ENV[$1] ||= $2
      end
    end
  rescue => e
    warn "[AgentMonitor] Failed to load .env: #{e.message}"
  end
end