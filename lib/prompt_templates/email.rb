# lib/prompt_templates/email.rb
# encoding: utf-8
# Template for email-related tasks

require_relative 'base'

module PromptTemplates
  class Email < Base
    def build
      parts = []
      parts << task_context
      parts << conversation_history unless comments.empty?
      parts << latest_request
      parts << "\n\n" + instructions

      parts.join.strip
    end

    private

    def instructions
      <<~INSTRUCTIONS
      INSTRUCTIONS:
      
      You are an AI assistant helping to draft emails.
      
      1. DRAFTING:
         - Write clear, professional emails based on the task context.
         - Pay attention to tone and audience. 
         
      2. OUTPUT REQUIREMENT:
         - You MUST include the full text of the email (Subject, To, Body) in your final response comments.
         - Do NOT just say 'I drafted the email'. Show the draft so the user can review it.
      INSTRUCTIONS
    end
  end
end