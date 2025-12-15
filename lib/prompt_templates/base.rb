# lib/prompt_templates/base.rb
# encoding: utf-8
# Base class for all prompt templates in the DPSY system

module PromptTemplates
  class Base
    attr_reader :task, :comments, :comment_text, :from_comment

    def initialize(task:, comments: [], comment_text: nil, from_comment: false)
      @task = task
      @comments = comments
      @comment_text = comment_text
      @from_comment = from_comment
    end

    def build
      raise NotImplementedError, "Subclasses must implement #build"
    end

    protected

    def task_context
      parts = []
      parts << "Task : #{safe_encode(task.name)}" if task.name && !task.name.strip.empty?
      parts << "\n\nNotes : #{safe_encode(task.notes)}" if task.notes && !task.notes.strip.empty?
      parts.join
    end

    def conversation_history
      return "" if comments.nil? || comments.empty?

      history = ["\n\n--- Conversation History ---"]
      comments.each do |comment|
        author = safe_encode(comment[:created_by] || "Unknown")
        timestamp = comment[:created_at] ? Time.parse(comment[:created_at]).strftime("%b %d, %I:%M %p") : "Unknown time"
        text = safe_encode(comment[:text] || "")

        history << "\n\n[#{author} - #{timestamp}]:"
        history << "\n#{text}"
      end
      history << "\n\n--- End Conversation History ---"
      history.join
    end

    def latest_request
      return "" unless from_comment && comment_text && !comment_text.strip.empty?
      "\n\nLatest Request : #{safe_encode(comment_text.strip)}"
    end

    def safety_rules
      # Override in subclasses to customize
      []
    end

    private

    def safe_encode(str)
      return "" if str.nil?
      str.encode('UTF-8', invalid: :replace, undef: :replace)
    end
  end
end
