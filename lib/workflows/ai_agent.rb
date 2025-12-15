# lib/workflows/ai_agent.rb
# encoding: utf-8

require_relative 'base'
require_relative '../llm/base_client'
require_relative '../asana_client'
require_relative '../task_classifier'
require_relative '../conversation_summarizer'
require_relative '../prompt_templates/simple_query'
require_relative '../prompt_templates/email'
require_relative '../prompt_templates/company_research'
require_relative '../prompt_templates/general'
require_relative '../task_decomposer'

require 'json'
require 'timeout'

module Workflows
  class AiAgent < Base
    def execute
      log_info("Executing AI workflow for task: #{task.name}")

      # Initialize LLM Client
      @llm_client = LLM::BaseClient.new

      begin
        Timeout.timeout(AgentConfig::TASK_TIMEOUT) do
          # GEPA: Check if task should be decomposed into steps
          if TaskDecomposer.should_decompose?(task, @comment_text)
            log_info("GEPA: Task requires decomposition - using multi-step execution")
            return execute_with_gepa
          end

          # Single-step execution
          execute_single_step
        end
      rescue Timeout::Error
        log_error("Workflow timed out")
        {
          success: false,
          error: "Workflow timeout",
          comment: "❌ Workflow timed out. Task may be too complex."
        }
      rescue => e
        log_error("Unexpected error in AI workflow: #{e.class}: #{e.message}")
        log_error(e.backtrace.first(5).join("\n"))
        {
          success: false,
          error: e.message,
          comment: "❌ Error: #{e.message}"
        }
      end
    end

    def execute_single_step
      # Build prompt from task content
      prompt = build_prompt

      log_info("Sending prompt to AI...")

      response = @llm_client.call(prompt)

      if response[:success]
        log_info("AI responded successfully")
        {
          success: true,
          comment: format_response(response[:output], response[:provider])
        }
      else
        log_error("AI workflow failed: #{response[:error]}")
        {
          success: false,
          error: response[:error],
          comment: "❌ AI error: #{response[:error]}"
        }
      end
    end

    def execute_with_gepa
      steps = TaskDecomposer.decompose(task, @comment_text)

      log_info("GEPA: Task decomposed into #{steps.size} step(s)")
      log_info("GEPA: Using sequential execution")

      execute_steps_sequential(steps)
    end

    def execute_steps_sequential(steps)
      results = []
      successful_steps = 0

      steps.each do |step|
        log_info("GEPA: Executing step #{step.number}/#{steps.size} : #{step.name}")
        add_progress_comment("🔄 Step #{step.number}/#{steps.size} : #{step.name}")

        # Execute with retry
        result = execute_step_with_retry(step)
        results << result

        if result[:success]
          successful_steps += 1
          summary = extract_summary(result[:output])
          log_info("GEPA: Step #{step.number} succeeded : #{summary}")
          add_progress_comment("✅ Step #{step.number} : #{summary}")
        else
          log_error("GEPA: Step #{step.number} failed : #{result[:error]}")
          add_progress_comment("❌ Step #{step.number} failed : #{result[:error]}")
        end
      end

      # Generate final summary
      {
        success: successful_steps > 0,
        comment: build_final_summary(steps.size, successful_steps, results)
      }
    end

    def execute_step_with_retry(step)
      result = nil
      begin
        # Per-step timeout : 10 minutes max
        Timeout.timeout(600) do
          result = execute_step(step)

          # Retry if step failed & retry is enabled
          if !result[:success] && step.retry_on_failure
            log_info("GEPA: Retrying step #{step.number} (1 retry attempt)")
            result = execute_step(step)

            if result[:success]
              log_info("GEPA: Step #{step.number} succeeded on retry")
            else
              log_error("GEPA: Step #{step.number} failed after retry")
            end
          end
        end
      rescue Timeout::Error
        log_error("GEPA: Step #{step.number} timed out")
        result = {
          success: false,
          error: "Step timeout"
        }
      end

      result
    end

    def execute_step(step)
      prompt = build_step_prompt(step)
      response = @llm_client.call(prompt)

      if response[:success]
        {
          success: true,
          output: response[:output],
          provider: response[:provider]
        }
      else
        {
          success: false,
          error: response[:error]
        }
      end
    end

    def build_step_prompt(step)
      parts = []
      parts << "Task Context : #{task.name}" if task.name && !task.name.strip.empty?
      parts << "\n\nOverall Goal : #{task.notes}" if task.notes && !task.notes.strip.empty?
      parts << "\n\nCurrent Step (#{step.number}) : #{step.description}"
      parts << "\n\nSuccess Criteria : #{step.success_criteria}"

      parts.join.strip
    end

    def add_progress_comment(text)
      log_info("Progress: #{text}")
      begin
        AsanaClient.add_comment(task_id: task.gid, comment: text)
      rescue => e
        log_error("Failed to post progress comment: #{e.message}")
      end
    end

    def extract_summary(output)
      lines = output.split("\n").reject { |l| l.strip.empty? }
      first_line = lines.first || ""
      first_line.strip[0..100]
    end

    def build_final_summary(total_steps, successful_steps, results)
      summary = "🤖 GEPA Multi-Step Execution:\n\n"
      summary += "Completed #{successful_steps}/#{total_steps} steps successfully.\n\n"

      if successful_steps == total_steps
        summary += "✅ All steps completed!\n\n"
      elsif successful_steps > 0
        summary += "⚠️ Partial completion.\n\n"
      else
        summary += "❌ No steps completed successfully.\n\n"
      end

      results.each_with_index do |result, index|
        step_num = index + 1
        if result[:success]
          clean_output = result[:output].strip
          
          # Truncate very long outputs unless they look like emails/code
          if clean_output.length > 5000 && !clean_output.match?(/ (Subject:|To:|From:)/i)
            clean_output = clean_output[0..5000] + "\n\n...(truncated)"
          end

          summary += "━━━ Step #{step_num} Result ━━━\n#{clean_output}\n\n"
        else
          summary += "━━━ Step #{step_num} Failed ━━━\nError : #{result[:error]}\n\n"
        end
      end

      summary
    end

    private

    def build_prompt
      # DPSY: Dynamic Prompt System - select template based on task type
      @task_type = TaskClassifier.classify(task, @comment_text)

      log_info("DPSY: Task classified as :#{@task_type}")

      # Summarize long conversation histories to save tokens
      summarized_comments = ConversationSummarizer.summarize_if_needed(all_comments)

      # Select appropriate template based on task type
      template_class = case @task_type
      when :simple_query      then PromptTemplates::SimpleQuery
      when :email             then PromptTemplates::Email
      when :company_research  then PromptTemplates::CompanyResearch
      else                         PromptTemplates::General
      end

      # Build prompt using selected template
      template = template_class.new(
        task: task,
        comments: summarized_comments,
        comment_text: @comment_text,
        from_comment: from_comment?
      )

      prompt = template.build
      prompt
    end

    def strip_markdown(text)
      result = text.dup
      result.gsub!(/```[a-z]*\n(.*?)\n```/m, '\1')
      result.gsub!(/`([^`]+)`/, '\1')
      result.gsub!(/\*\*([^*]+)\*\*/, '\1')
      result.gsub!(/\*([^*]+)\*/, '\1')
      result.gsub!(/^[#]{1,6}\s+(.+)$/, '\1')
      result.gsub!(/!\[([^\]]+)\]\([^)]+\)/, '\1')
      result.gsub!(/<[^>]+>/, '')
      result
    end

    def format_response(output, provider)
      provider_name = provider.to_s.capitalize
      plain_output = strip_markdown(output)
      "🤖 #{provider_name} Response:\n\n#{plain_output}"
    end
  end
end
