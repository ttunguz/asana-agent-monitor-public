# lib/llm/prompt_engineer.rb
# Smart prompt engineering with validation, compression, and safety checks
# encoding: utf-8

require 'json'
require 'digest'

module LLM
  class PromptEngineer
    # Token limits for different models (leaving room for response)
    MODEL_LIMITS = {
      'claude-3-opus' => { total: 200_000, reserved_output: 4_000 },
      'claude-3-sonnet' => { total: 200_000, reserved_output: 4_000 },
      'claude-3-haiku' => { total: 200_000, reserved_output: 4_000 },
      'gemini-pro' => { total: 32_000, reserved_output: 2_000 },
      'gemini-flash' => { total: 32_000, reserved_output: 2_000 },
      'gpt-4-turbo' => { total: 128_000, reserved_output: 4_000 }
    }

    # Dangerous patterns that might indicate prompt injection
    INJECTION_PATTERNS = [
      /ignore.*(?:previous|prior|above).*instructions?/i,
      /disregard.*(?:all|any).*(?:previous|prior|above)/i,
      /forget.*everything.*(?:said|told)/i,
      /system.*(?:prompt|message|instruction)/i,
      /new.*instructions?.*follow/i,
      /actually.*i.*am/i,
      /pretend.*you.*are/i,
      /roleplay|act\s+as/i,
      /\bsudo\b/i,
      /admin.*mode/i
    ]

    # Safety patterns to check in prompts
    DANGEROUS_COMMANDS = [
      /rm\s+-rf?\s+\//,            # Destructive file operations
      /mkfs/,                       # Format filesystem
      /dd\s+if=/,                   # Disk operations
      /:(\/\/|\\\\)/,              # Network operations
      /curl.*\|\s*sh/,             # Remote code execution
      /wget.*\|\s*bash/,           # Remote code execution
      />\/dev\/sda/,               # Direct disk writes
      /fork\s*bomb/i,              # Fork bombs
      /\$\(.*\$\(.*\$\(/           # Nested command substitution
    ]

    def initialize(logger: nil)
      @logger = logger || Logger.new(STDOUT)
      @prompt_cache = {}
      @template_cache = {}
    end

    def build_prompt(task:, context: {}, model: 'claude-3-sonnet', options: {})
      # Start with base prompt
      prompt_parts = []

      # Add system instructions based on task type
      prompt_parts << generate_system_instructions(task[:type])

      # Add few-shot examples if available
      if examples = load_examples_for_task(task[:type])
        prompt_parts << format_examples(examples)
      end

      # Add main task content
      prompt_parts << format_task(task)

      # Add context if provided
      if context && !context.empty?
        prompt_parts << format_context(context, model)
      end

      # Add output format instructions
      prompt_parts << generate_output_instructions(task[:type], options[:structured])

      # Add safety instructions
      prompt_parts << safety_instructions

      # Combine all parts
      full_prompt = prompt_parts.compact.join("\n\n")

      # Validate prompt safety
      validate_prompt_safety(full_prompt)

      # Compress if needed
      compressed_prompt = compress_if_needed(full_prompt, model)

      # Cache the prompt
      cache_prompt(task, compressed_prompt)

      compressed_prompt
    end

    def generate_system_instructions(task_type)
      base_instructions = <<~INSTRUCTIONS
        You are an AI assistant helping with task automation for Theory Ventures.
        Follow these guidelines:
        1. Be precise and actionable in your responses
        2. Use the Code Mode APIs in ~/.gemini/code_mode/ for all operations
        3. Include error handling in all generated code
        4. Provide clear explanations for your actions
      INSTRUCTIONS

      # Add task-specific instructions
      case task_type
      when :email
        base_instructions + email_instructions
      when :company_research
        base_instructions + company_instructions
      when :task_management
        base_instructions + task_instructions
      else
        base_instructions + general_instructions
      end
    end

    def email_instructions
      <<~INSTRUCTIONS

        EMAIL-SPECIFIC INSTRUCTIONS:
        - Always use EmailAPI from ~/.gemini/code_mode/email_api.rb
        - Use format: :concise for bulk operations to save tokens
        - Use parallel_search for multiple email queries (2-5x faster)
        - Handle encoding with .force_encoding('UTF-8').scrub
        - Example:
          ```ruby
          require_relative '/Users/tomasztunguz/.gemini/code_mode/email_api'

          # Single search
          emails = EmailAPI.search(from: "sender@example.com", limit: 3, format: :concise)

          # Parallel search for multiple queries
          results = EmailAPI.parallel_search([
            {from: "person1@example.com", limit: 3, format: :ids_only},
            {from: "person2@example.com", limit: 3, format: :ids_only}
          ])
          ```
      INSTRUCTIONS
    end

    def company_instructions
      <<~INSTRUCTIONS

        COMPANY RESEARCH INSTRUCTIONS:
        - Always use AttioAPI for CRM operations
        - Use ResearchAPI for enrichment and analysis
        - Use find_or_create to prevent duplicate errors
        - Example:
          ```ruby
          require_relative '/Users/tomasztunguz/.gemini/code_mode/attio_api'
          require_relative '/Users/tomasztunguz/.gemini/code_mode/research_api'

          # Find or create company
          company = AttioAPI.find_or_create(
            domain: "example.com",
            name: "Example Inc",
            source: "referral"
          )

          # Get traction data
          metrics = ResearchAPI.harmonic_company(domain: "example.com", format: :table)
          ```
      INSTRUCTIONS
    end

    def task_instructions
      <<~INSTRUCTIONS

        TASK MANAGEMENT INSTRUCTIONS:
        - Always use TaskAPI from ~/.gemini/code_mode/task_api.rb
        - Valid assignees: "tom", "art", "lauren"
        - Use ISO date format for due dates
        - Example:
          ```ruby
          require_relative '/Users/tomasztunguz/.gemini/code_mode/task_api'

          TaskAPI.create(
            title: "Review document",
            assignee: "tom",
            due_date: "2025-01-15",
            notes: "Priority: High"
          )
          ```
      INSTRUCTIONS
    end

    def general_instructions
      <<~INSTRUCTIONS

        GENERAL AUTOMATION INSTRUCTIONS:
        - Prefer Code Mode APIs over direct commands
        - Include appropriate error handling
        - Log important operations
        - Validate inputs before processing
      INSTRUCTIONS
    end

    def format_task(task)
      formatted = "## Current Task\n\n"

      if task[:name]
        formatted += "**Task Name:** #{task[:name]}\n\n"
      end

      if task[:description]
        formatted += "**Description:** #{task[:description]}\n\n"
      end

      if task[:notes]
        formatted += "**Notes:**\n#{task[:notes]}\n\n"
      end

      if task[:comments] && !task[:comments].empty?
        formatted += format_comments(task[:comments])
      end

      formatted
    end

    def format_comments(comments)
      formatted = "**Conversation History:**\n\n"

      comments.each do |comment|
        timestamp = comment[:created_at] || "Unknown time"
        author = comment[:created_by] || "Unknown"
        text = comment[:text] || ""

        formatted += "---\n"
        formatted += "**[#{author} - #{timestamp}]:**\n"
        formatted += "#{text}\n\n"
      end

      formatted + "---\n\n"
    end

    def format_context(context, model)
      # Intelligently format and prioritize context
      max_context_tokens = calculate_context_budget(model)

      formatted = "## Additional Context\n\n"

      # Priority order for context items
      priority_order = [:recent_activity, :related_tasks, :user_preferences, :historical_data]

      used_tokens = 0
      priority_order.each do |key|
        next unless context[key]

        section = format_context_section(key, context[key])
        section_tokens = estimate_tokens(section)

        if used_tokens + section_tokens < max_context_tokens
          formatted += section
          used_tokens += section_tokens
        else
          # Truncate if needed
          remaining = max_context_tokens - used_tokens
          formatted += truncate_text(section, remaining)
          formatted += "\n[Context truncated due to length]\n"
          break
        end
      end

      formatted
    end

    def format_context_section(key, value)
      title = key.to_s.split('_').map(&:capitalize).join(' ')
      "### #{title}\n\n#{value}\n\n"
    end

    def generate_output_instructions(task_type, structured = false)
      base = "## Output Requirements\n\n"

      if structured
        base += structured_output_instructions(task_type)
      else
        base += standard_output_instructions
      end

      base
    end

    def structured_output_instructions(task_type)
      <<~INSTRUCTIONS
        Please provide your response in the following JSON structure:

        ```json
        {
          "action": "description of action taken",
          "code": "executable code if applicable",
          "result": "expected outcome",
          "confidence": 0.0-1.0,
          "reasoning": "explanation of approach",
          "warnings": ["any potential issues"],
          "next_steps": ["suggested follow-up actions"]
        }
        ```

        Ensure the JSON is valid and properly escaped.
      INSTRUCTIONS
    end

    def standard_output_instructions
      <<~INSTRUCTIONS
        Structure your response as follows:
        1. Brief summary of what you're going to do
        2. Code implementation (if applicable)
        3. Explanation of the approach
        4. Any warnings or considerations
        5. Suggested next steps
      INSTRUCTIONS
    end

    def safety_instructions
      <<~SAFETY
        ## Safety Requirements

        CRITICAL SAFETY RULES:
        1. DO NOT run destructive commands (rm -rf, format, etc.)
        2. DO NOT expose API keys or credentials in output
        3. DO NOT make unauthorized external network requests
        4. DO NOT execute code from untrusted sources
        5. VALIDATE all inputs before processing
        6. USE try/rescue blocks for error handling
        7. LOG important operations for audit trail
      SAFETY
    end

    def validate_prompt_safety(prompt)
      # Check for injection attempts
      INJECTION_PATTERNS.each do |pattern|
        if prompt.match?(pattern)
          @logger.warn("Potential prompt injection detected: #{pattern}")
          raise SecurityError, "Prompt contains suspicious patterns that may indicate injection attempt"
        end
      end

      # Check for dangerous commands
      DANGEROUS_COMMANDS.each do |pattern|
        if prompt.match?(pattern)
          @logger.error("Dangerous command pattern detected: #{pattern}")
          raise SecurityError, "Prompt contains potentially destructive commands"
        end
      end

      # Check for credential exposure
      if prompt.match?(/(?:api[_-]?key|password|token|secret).*[:=].*/i)
        @logger.warn("Potential credential exposure in prompt")
        # Sanitize instead of rejecting
        prompt.gsub!(/(?:api[_-]?key|password|token|secret).*[:=]\S+/i, '[REDACTED]')
      end

      true
    end

    def compress_if_needed(prompt, model)
      limit = MODEL_LIMITS[model] || MODEL_LIMITS['gemini-pro']
      max_tokens = limit[:total] - limit[:reserved_output]
      current_tokens = estimate_tokens(prompt)

      if current_tokens <= max_tokens
        return prompt
      end

      @logger.info("Compressing prompt from #{current_tokens} to fit #{max_tokens} tokens")

      # Progressive compression strategies
      compressed = prompt

      # 1. Remove extra whitespace
      compressed = compressed.gsub(/\n{3,}/, "\n\n").gsub(/\s+/, ' ')
      return compressed if estimate_tokens(compressed) <= max_tokens

      # 2. Remove examples if present
      compressed = compressed.gsub(/### Examples?.*?(?=###|\z)/m, '')
      return compressed if estimate_tokens(compressed) <= max_tokens

      # 3. Truncate conversation history
      compressed = truncate_conversation_history(compressed)
      return compressed if estimate_tokens(compressed) <= max_tokens

      # 4. Aggressive truncation
      truncate_to_token_limit(compressed, max_tokens)
    end

    def truncate_conversation_history(prompt)
      # Keep only last 3 comments
      lines = prompt.lines
      comment_indices = []

      lines.each_with_index do |line, i|
        if line.match?(/^\*\*\[.*\]:\*\*$/)
          comment_indices << i
        end
      end

      if comment_indices.size > 3
        # Keep first part and last 3 comments
        cutoff = comment_indices[-3]
        kept_lines = lines[0...comment_indices[0]] +
                    ["[Previous conversation truncated...]\n"] +
                    lines[cutoff..-1]
        kept_lines.join
      else
        prompt
      end
    end

    def truncate_to_token_limit(text, max_tokens)
      # Rough truncation based on token estimate
      max_chars = max_tokens * 4  # Approximate 4 chars per token

      if text.length > max_chars
        text[0...max_chars] + "\n\n[TRUNCATED due to length constraints]"
      else
        text
      end
    end

    def estimate_tokens(text)
      # Simple estimation: ~4 characters per token on average
      (text.length / 4.0).ceil
    end

    def calculate_context_budget(model)
      limit = MODEL_LIMITS[model] || MODEL_LIMITS['gemini-pro']
      total_budget = limit[:total] - limit[:reserved_output]

      # Reserve 50% for context, 50% for main prompt
      (total_budget * 0.5).to_i
    end

    def load_examples_for_task(task_type)
      # Load cached examples for few-shot learning
      examples_file = File.join(__dir__, '..', '..', 'prompts', 'examples', "#{task_type}.json")

      if File.exist?(examples_file)
        JSON.parse(File.read(examples_file), symbolize_names: true)
      else
        nil
      end
    end

    def format_examples(examples)
      return "" if examples.nil? || examples.empty?

      formatted = "### Examples\n\n"

      examples.first(3).each_with_index do |example, i|
        formatted += "**Example #{i + 1}:**\n"
        formatted += "Input: #{example[:input]}\n"
        formatted += "Output: #{example[:output]}\n\n"
      end

      formatted
    end

    def cache_prompt(task, prompt)
      # Cache prompts for potential reuse
      cache_key = Digest::SHA256.hexdigest(task.to_json)
      @prompt_cache[cache_key] = {
        prompt: prompt,
        timestamp: Time.now,
        task_type: task[:type]
      }

      # Clean old cache entries (older than 1 hour)
      @prompt_cache.delete_if { |_, v| Time.now - v[:timestamp] > 3600 }
    end

    def get_cached_prompt(task)
      cache_key = Digest::SHA256.hexdigest(task.to_json)
      cached = @prompt_cache[cache_key]

      if cached && Time.now - cached[:timestamp] < 3600
        @logger.info("Using cached prompt for task")
        cached[:prompt]
      else
        nil
      end
    end

    # Security error class
    class SecurityError < StandardError; end
  end
end