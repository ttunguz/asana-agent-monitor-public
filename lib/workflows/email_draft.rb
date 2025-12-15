# lib/workflows/email_draft.rb

require_relative 'base'

module Workflows
  class EmailDraft < Base
    def execute
      log_info("Drafting email from task: #{task.name}")

      # Parse recipient from task title or notes
      recipient_info = parse_recipient

      unless recipient_info[:success]
        return {
          success: false,
          error: recipient_info[:error],
          comment: "❌ Could not determine email recipient. Please include a name or email address in the task."
        }
      end

      # Extract subject & body hints
      subject = extract_subject
      body_hint = extract_body_hint

      # Generate draft preview
      draft_preview = format_draft_preview(
        recipient_info[:recipient],
        subject,
        body_hint
      )

      # Add draft preview as comment
      {
        success: true,
        comment: "✅ Email draft prepared:\n\n#{draft_preview}\n\n_Please review & send manually._"
      }
    rescue => e
      log_error("Email draft failed: #{e.message}")

      {
        success: false,
        error: e.message,
        comment: "❌ Failed to draft email: #{e.message}"
      }
    end

    private

    def parse_recipient
      # Extract from patterns like "Email Jamie" or "Draft email to jamie@example.com"
      text = "#{task.name} #{task.notes}".strip

      # Try to find email address first
      if text.match?(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/)
        email = text.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/)[0]
        return { success: true, recipient: email, type: :email }
      end

      # Try to extract name after "email" keyword
      if text.match?(/email\s+(\w+)/i)
        name = text.match(/email\s+(\w+)/i)[1]
        return { success: true, recipient: name, type: :name }
      end

      # Try "to [name]" pattern
      if text.match?(/to\s+(\w+)/i)
        name = text.match(/to\s+(\w+)/i)[1]
        return { success: true, recipient: name, type: :name }
      end

      { success: false, error: "Could not extract recipient from task" }
    end

    def extract_subject
      # Look for "about [subject]" pattern
      text = "#{task.name} #{task.notes}"

      if text.match?(/about\s+(.+?)(\.||$)/i)
        text.match(/about\s+(.+?)(\.||$)/i)[1].strip
      else
        "Follow-up"
      end
    end

    def extract_body_hint
      # Use task notes as body hint if available
      task.notes.to_s.strip.empty? ? nil : task.notes.strip
    end

    def format_draft_preview(recipient, subject, body_hint)
      preview = "To : #{recipient}\n"
      preview += "Subject : #{subject}\n\n"
      preview += "Body :\n"

      if body_hint
        preview += body_hint + "\n\n"
      else
        preview += "[Draft body here - provide context in task notes for better suggestions]\n\n"
      end

      preview
    end
  end
end