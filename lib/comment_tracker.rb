# lib/comment_tracker.rb
# Tracks which comments have been processed to avoid duplicate responses

require 'json'
require 'fileutils'

class CommentTracker
  def initialize(state_file = nil)
    @state_file = state_file || File.join(__dir__, '../logs/processed_comments.json')
    @mutex = Mutex.new
    @state = load_state
  end

  # Check if a comment has been processed
  def processed?(task_gid, comment_gid)
    @mutex.synchronize do
      return false unless @state[task_gid]
      @state[task_gid].key?(comment_gid)
    end
  end

  # Mark a comment as processed
  def mark_processed(task_gid, comment_gid)
    @mutex.synchronize do
      @state[task_gid] ||= {}
      @state[task_gid][comment_gid] = Time.now.utc.iso8601
      save_state
    end
  end

  # Get all processed comments for a task
  def processed_comments(task_gid)
    @mutex.synchronize do
      @state[task_gid] || {}
    end
  end

  # Clean up old state (comments older than days)
  def cleanup_old_state(days = 30)
    cutoff = Time.now - (days * 24 * 60 * 60)

    @mutex.synchronize do
      @state.each do |task_gid, comments|
        comments.delete_if do |comment_gid, timestamp|
          Time.parse(timestamp) < cutoff
        end
        @state.delete(task_gid) if comments.empty?
      end

      save_state
    end
  end

  private

  def load_state
    return {} unless File.exist?(@state_file)

    begin
      JSON.parse(File.read(@state_file))
    rescue JSON::ParserError => e
      warn "Warning: Could not parse state file #{@state_file}: #{e.message}"
      warn "Starting with fresh state"
      {}
    end
  end

  def save_state
    # Ensure directory exists
    FileUtils.mkdir_p(File.dirname(@state_file))

    File.write(@state_file, JSON.pretty_generate(@state))
  end
end
