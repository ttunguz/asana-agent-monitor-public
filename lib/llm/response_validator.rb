# lib/llm/response_validator.rb
# Validates and sanitizes LLM responses for safety and correctness
# encoding: utf-8

require 'json'
require 'ripper'

module LLM
  class ResponseValidator
    # Dangerous patterns in generated code
    DANGEROUS_PATTERNS = [
      # File system destruction
      { pattern: /rm\s+-rf?\s+\//, risk: :critical, message: "Destructive file deletion detected" },
      { pattern: /mkfs/, risk: :critical, message: "Filesystem format command detected" },
      { pattern: /dd\s+if=.*of=\/dev/, risk: :critical, message: "Direct disk write detected" },

      # Network risks
      { pattern: /curl.*\|\s*(bash|sh)/, risk: :high, message: "Remote code execution detected" },
      { pattern: /wget.*\|\s*(bash|sh)/, risk: :high, message: "Remote code execution detected" },
      { pattern: /nc\s+-l/, risk: :medium, message: "Network listener detected" },

      # Credential exposure
      { pattern: /(?:api[_-]?key|password|token|secret)\s*[:=]\s*["'][\w\-]+["']/i, risk: :high, message: "Potential credential exposure" },
      { pattern: /ENV\[["'](?:.*KEY|.*TOKEN|.*SECRET)["']\]/, risk: :medium, message: "Environment variable access" },

      # Code execution
      { pattern: /eval\s*\(/, risk: :high, message: "Dynamic code evaluation detected" },
      { pattern: /exec\s*\(/, risk: :high, message: "Dynamic code execution detected" },
      { pattern: /system\s*\(/, risk: :medium, message: "System command execution" },
      { pattern: /`[^`]+`/, risk: :low, message: "Backtick command execution" },
      { pattern: /%x\{/, risk: :low, message: "Percent-x command execution" },

      # Process manipulation
      { pattern: /fork\s*\{\s*fork/, risk: :critical, message: "Fork bomb pattern detected" },
      { pattern: /Process\.kill/, risk: :medium, message: "Process termination detected" },
      { pattern: /Signal\.trap/, risk: :low, message: "Signal handling detected" },

      # Resource exhaustion
      { pattern: /loop\s*do\s*\z/, risk: :medium, message: "Infinite loop risk" },
      { pattern: /while\s+true/, risk: :low, message: "Potentially infinite loop" },
      { pattern: /sleep\s*\(\s*\d{4,}/, risk: :low, message: "Long sleep detected" }
    ]

    # Required patterns for proper code structure
    REQUIRED_PATTERNS = {
      error_handling: /(?:begin|rescue|ensure|try|catch|error)/,
      logging: /(?:log|logger|puts|print|@logger)/,
      validation: /(?:validate|valid\?|check|verify|nil\?|empty\?)/
    }

    def initialize(logger: nil)
      @logger = logger || Logger.new(STDOUT)
      @validation_stats = Hash.new(0)
    end

    def validate(response, options = {})
      return invalid_response("Empty response") if response.nil? || response.empty?

      # Parse response based on type
      parsed = parse_response(response, options[:format])
      return parsed unless parsed[:success]

      # Extract code blocks if present
      code_blocks = extract_code_blocks(parsed[:content])

      # Validate each code block
      validation_results = code_blocks.map do |block|
        validate_code_block(block, options)
      end

      # Check for any critical issues
      critical_issues = validation_results.select { |r| r[:risk_level] == :critical }
      if critical_issues.any?
        return {
          success: false,
          error: "Critical security issues detected",
          issues: critical_issues,
          sanitized: nil
        }
      end

      # Sanitize and return
      {
        success: true,
        content: parsed[:content],
        code_blocks: code_blocks,
        validation: validation_results,
        sanitized: sanitize_response(parsed[:content], validation_results),
        confidence: calculate_confidence(validation_results)
      }
    end

    def report_stats
      @validation_stats
    end

    private

    def parse_response(response, format)
      case format
      when :json
        parse_json_response(response)
      when :structured
        parse_structured_response(response)
      else
        parse_text_response(response)
      end
    rescue => e
      @logger.error("Failed to parse response: #{e.message}")
      invalid_response("Parse error: #{e.message}")
    end

    def parse_json_response(response)
      # Try to extract JSON from the response
      json_match = response.match(/\{.*\}/m)
      unless json_match
        return invalid_response("No JSON found in response")
      end

      begin
        parsed = JSON.parse(json_match[0], symbolize_names: true)
        {
          success: true,
          content: response,
          data: parsed
        }
      rescue JSON::ParserError => e
        invalid_response("Invalid JSON: #{e.message}")
      end
    end

    def parse_structured_response(response)
      # Parse structured format (action, code, reasoning, etc.)
      sections = {}

      # Extract sections based on headers
      current_section = nil
      response.lines.each do |line|
        if line.match?(/^#+\s+(.+)/)
          current_section = line.match(/^#+\s+(.+)/)[1].downcase.gsub(/\s+/, '_').to_sym
          sections[current_section] = ""
        elsif current_section
          sections[current_section] += line
        end
      end

      if sections.empty?
        parse_text_response(response)
      else
        {
          success: true,
          content: response,
          sections: sections
        }
      end
    end

    def parse_text_response(response)
      {
        success: true,
        content: response,
        type: :text
      }
    end

    def extract_code_blocks(content)
      blocks = []

      # Match code blocks with optional language specification
      content.scan(/```(\w*)\n(.*?)```/m) do |language, code|
        blocks << {
          language: language.empty? ? 'unknown' : language,
          code: code.strip,
          line_count: code.lines.count
        }
      end

      # Also check for inline code that might be executable
      if blocks.empty? && content.match?(/^\s*(require|class|def|module)\s+/)
        # Treat entire content as Ruby code if it starts with Ruby keywords
        blocks << {
          language: 'ruby',
          code: content,
          line_count: content.lines.count
        }
      end

      blocks
    end

    def validate_code_block(block, options)
      language = block[:language].downcase
      code = block[:code]

      validation = {
        language: language,
        line_count: block[:line_count],
        issues: [],
        risk_level: :safe,
        has_error_handling: false,
        has_logging: false,
        has_validation: false
      }

      # Skip validation for non-executable languages
      return validation if %w[markdown md text plain].include?(language)

      # Check for dangerous patterns
      DANGEROUS_PATTERNS.each do |check|
        if code.match?(check[:pattern])
          validation[:issues] << {
            type: :security,
            risk: check[:risk],
            message: check[:message],
            pattern: check[:pattern].to_s
          }
          # Update overall risk level
          validation[:risk_level] = higher_risk(validation[:risk_level], check[:risk])
        end
      end

      # Check for required patterns (for Ruby code)
      if language == 'ruby' || language == 'rb'
        validate_ruby_code(code, validation)
      end

      # Check for missing safety features
      REQUIRED_PATTERNS.each do |feature, pattern|
        if code.match?(pattern)
          validation[:"has_#{feature}"] = true
        elsif options[:require_safety_features]
          validation[:issues] << {
            type: :missing_feature,
            risk: :low,
            message: "Missing #{feature.to_s.gsub('_', ' ')}"
          }
        end
      end

      validation
    end

    def validate_ruby_code(code, validation)
      begin
        # Use Ripper for syntax checking
        syntax_errors = []

        # Check if code is syntactically valid
        if Ripper.sexp(code).nil?
          validation[:issues] << {
            type: :syntax,
            risk: :high,
            message: "Invalid Ruby syntax"
          }
          validation[:risk_level] = higher_risk(validation[:risk_level], :high)
          return
        end

        # Additional Ruby-specific checks
        check_ruby_specific_patterns(code, validation)

      rescue => e
        validation[:issues] << {
          type: :parse_error,
          risk: :medium,
          message: "Failed to parse Ruby code: #{e.message}"
        }
      end
    end

    def check_ruby_specific_patterns(code, validation)
      # Check for unbounded loops
      if code.match?(/loop\s+do\s*$/) || code.match?(/while\s+true\s*$/)
        unless code.match?(/break|return|exit/)
          validation[:issues] << {
            type: :logic,
            risk: :medium,
            message: "Potentially infinite loop without break condition"
          }
          validation[:risk_level] = higher_risk(validation[:risk_level], :medium)
        end
      end

      # Check for file operations without proper checks
      if code.match?(/File\.(open|write|delete|unlink)/)
        unless code.match?(/File\.exist\?|File\.file\?|File\.directory\?/)
          validation[:issues] << {
            type: :safety,
            risk: :low,
            message: "File operations without existence checks"
          }
        end
      end

      # Check for network operations
      if code.match?(/Net::HTTP|RestClient|HTTParty|Faraday/)
        unless code.match?(/timeout|open_timeout|read_timeout/)
          validation[:issues] << {
            type: :reliability,
            risk: :low,
            message: "Network operations without timeout"
          }
        end
      end

      # Check for proper resource cleanup
      if code.match?(/\.(open|new)\s*\(/) && !code.match?(/\.(close|ensure)/)
        validation[:issues] << {
          type: :resource,
          risk: :low,
          message: "Resource allocation without cleanup"
        }
      end
    end

    def sanitize_response(content, validation_results)
      sanitized = content.dup

      # Remove or replace dangerous patterns
      validation_results.each do |validation|
        next unless validation[:issues].any?

        validation[:issues].each do |issue|
          if issue[:risk] == :critical || issue[:risk] == :high
            # Comment out dangerous code
            if issue[:pattern]
              sanitized.gsub!(/^(.*#{Regexp.escape(issue[:pattern])}.*)$/, '# SANITIZED: \1')
            end
          end
        end
      end

      # Add safety wrapper if code doesn't have error handling
      unless validation_results.all? { |v| v[:has_error_handling] }
        sanitized = wrap_in_error_handling(sanitized)
      end

      sanitized
    end

    def wrap_in_error_handling(code)
      <<~WRAPPED
        begin
          # AI-generated code with safety wrapper
          #{code}
        rescue StandardError => e
          puts "Error executing AI-generated code: \#{e.message}"
          puts "Backtrace: \#{e.backtrace.first(5).join('\n')}"
          # Log error for debugging
          File.open('/tmp/ai_error.log', 'a') do |f|
            f.puts "[#{Time.now.iso8601}] Error: \#{e.message}"
          end
          raise
        ensure
          # Cleanup any resources if needed
        end
      WRAPPED
    end

    def calculate_confidence(validation_results)
      total_issues = validation_results.sum { |v| v[:issues].size }
      critical_issues = validation_results.sum { |v| v[:issues].count { |i| i[:risk] == :critical } }
      high_issues = validation_results.sum { |v| v[:issues].count { |i| i[:risk] == :high } }

      # Start with 100% confidence
      confidence = 1.0

      # Reduce confidence based on issues
      confidence -= critical_issues * 0.3
      confidence -= high_issues * 0.15
      confidence -= (total_issues - critical_issues - high_issues) * 0.05

      # Boost confidence if safety features are present
      safety_features = validation_results.count { |v| v[:has_error_handling] && v[:has_logging] }
      confidence += safety_features * 0.05

      # Ensure confidence stays in valid range
      [[confidence, 0.0].max, 1.0].min
    end

    def higher_risk(current, new_risk)
      risk_levels = { safe: 0, low: 1, medium: 2, high: 3, critical: 4 }
      risk_levels[new_risk] > risk_levels[current] ? new_risk : current
    end

    def invalid_response(message)
      {
        success: false,
        error: message,
        content: nil
      }
    end

    def track_validation_stats(validation_results)
      @validation_stats[:total] += 1
      validation_results.each do |validation|
        @validation_stats[:risk_levels] ||= Hash.new(0)
        @validation_stats[:risk_levels][validation[:risk_level]] += 1

        validation[:issues].each do |issue|
          @validation_stats[:issue_types] ||= Hash.new(0)
          @validation_stats[:issue_types][issue[:type]] += 1
        end
      end
    end
  end
end