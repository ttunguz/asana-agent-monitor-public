# lib/workflows/open_url.rb

require_relative 'base'

module Workflows
  class OpenURL < Base
    def execute
      url = normalize_url(task.name.strip)

      log_info("Opening URL: #{url}")

      # Open URL in default browser
      system("open", url)

      {
        success: true,
        comment: "✅ Opened #{url} in browser"
      }
    rescue => e
      log_error("Failed to open URL: #{e.message}")
      {
        success: false,
        error: e.message,
        comment: "❌ Failed to open URL: #{e.message}"
      }
    end

    private

    def normalize_url(url)
      # Add https:// if missing
      url.start_with?('http') ? url : "https://#{url}"
    end
  end
end
