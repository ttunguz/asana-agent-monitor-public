# lib/prompt_templates/simple_query.rb
# encoding: utf-8
# Minimal template for simple questions (no API documentation needed)

require_relative 'base'

module PromptTemplates
  class SimpleQuery < Base
    def build
      parts = []
      parts << task_context
      parts << conversation_history unless comments.empty?
      parts << latest_request

      parts.join.strip
    end
  end
end
