# lib/prompt_templates/company_research.rb
# encoding: utf-8
# Template for company research tasks

require_relative 'base'

module PromptTemplates
  class CompanyResearch < Base
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
      
      You are an AI research assistant.
      
      1. RESEARCH:
         - Analyze the companies or markets mentioned.
         - Provide key metrics, business model, and competitive landscape.
         - Use your internal knowledge to provide insights.

      2. OUTPUT:
         - Provide a clear, structured summary.
         - Use markdown for readability.
      INSTRUCTIONS
    end
  end
end