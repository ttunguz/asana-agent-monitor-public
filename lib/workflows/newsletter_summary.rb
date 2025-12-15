# lib/workflows/newsletter_summary.rb

require_relative 'base'
require 'date'

module Workflows
  class NewsletterSummary < Base
    def execute
      log_info("Processing newsletter summary request...")

      # Determine date range (default: last 7 days)
      days = extract_days_from_task || 7
      start_date = Date.today - days

      log_info("  Processing newsletters from last #{days} days...")

      # Fetch recent newsletter emails
      # Note: This requires an Email provider implementation
      newsletters = fetch_newsletters(days)

      if newsletters.empty?
        return {
          success: false,
          error: "Email provider not configured",
          comment: "⚠️ Newsletter summary requires an Email provider integration. Please implement `fetch_newsletters` in `lib/workflows/newsletter_summary.rb`."
        }
      end

      log_info("  Found #{newsletters.size} newsletters")

      # Generate summary
      summary = generate_newsletter_summary(newsletters, days)

      # Create digest task for user
      tom_task = nil
      unless from_comment?
        log_info("  Creating digest task...")
        tom_task = create_followup_task(
          title: "Newsletter digest - #{start_date} to #{Date.today}",
          notes: summary
        )
      else
        log_info("  Skipping task creation (triggered by comment)")
      end

      comment = "✅ Newsletter digest created (#{newsletters.size} newsletters processed)"
      comment += "\n\nDigest task created." if tom_task

      {
        success: true,
        comment: comment
      }
    rescue => e
      log_error("Newsletter summary failed: #{e.message}")

      {
        success: false,
        error: e.message,
        comment: "❌ Failed to process newsletters: #{e.message}"
      }
    end

    private

    def extract_days_from_task
      # Look for patterns like "last 7 days", "past week", "this week"
      text = "#{task.name} #{task.notes}".downcase

      # Try to extract number of days
      if text.match?(/last\s+(\d+)\s+days?)
        text.match(/last\s+(\d+)\s+days?/)[1].to_i
      elsif text.match?(/past\s+(\d+)\s+days?)
        text.match(/past\s+(\d+)\s+days?/)[1].to_i
      elsif text.match?(/this week/)
        7
      elsif text.match?(/this month/)
        30
      else
        nil
      end
    end

    def fetch_newsletters(days)
      # Placeholder for Email integration
      # To enable this, integrate with your email provider (Gmail, IMAP, etc.)
      # Return array of hashes: { subject: '...', from: '...', date: '...', preview: '...' }
      
      log_info("Fetch newsletters not implemented in open source version")
      [] 
    end

    def generate_newsletter_summary(newsletters, days)
      summary = "Newsletter Digest\n\n"
      summary += "Period : Last #{days} days\n"
      summary += "Count : #{newsletters.size} newsletters\n\n"
      summary += "---\n\n"

      newsletters.each_with_index do |newsletter, index|
        summary += "#{index + 1}. #{newsletter[:subject]}\n"
        summary += "From : #{newsletter[:from]}\n"
        summary += "Date : #{newsletter[:date]}\n\n"

        # Add preview if available
        if newsletter[:preview]
          summary += "Preview :\n#{newsletter[:preview]}\n\n"
        end

        summary += "---\n\n"
      end

      summary
    end
  end
end