# lib/llm/claude_client.rb
# Anthropic Claude AI client

require_relative 'base_client'

module LLM
  class ClaudeClient < ClientBase
    API_BASE = "https://api.anthropic.com"
    API_VERSION = "2023-06-01"

    def call(prompt, max_tokens: 4096, temperature: 0.7)
      url = "#{API_BASE}/v1/messages"

      body = {
        model: model,
        max_tokens: max_tokens,
        temperature: temperature,
        messages: [{
          role: "user",
          content: prompt
        }]
      }

      headers = {
        'Content-Type' => 'application/json',
        'x-api-key' => api_key,
        'anthropic-version' => API_VERSION
      }

      response = make_request(url, headers, body)

      if response.code == '200'
        data = JSON.parse(response.body, symbolize_names: true)

        # Extract text from response
        text = data.dig(:content, 0, :text) || ''

        # Get token usage
        input_tokens = data.dig(:usage, :input_tokens) || estimate_tokens(prompt)
        output_tokens = data.dig(:usage, :output_tokens) || estimate_tokens(text)

        {
          success: true,
          output: text.strip,
          model: model,
          provider: :claude,
          tokens: {
            input: input_tokens,
            output: output_tokens,
            total: input_tokens + output_tokens
          }
        }
      else
        error_data = JSON.parse(response.body) rescue {}
        error_message = error_data.dig(:error, :message) || response.body

        {
          success: false,
          error: "Claude API error (#{response.code}): #{error_message}",
          model: model,
          provider: :claude
        }
      end
    rescue => e
      {
        success: false,
        error: "Claude client error: #{e.message}",
        model: model,
        provider: :claude
      }
    end
  end
end
