# lib/llm/gemini_client.rb
# Google Gemini AI client

require_relative 'base_client'

module LLM
  class GeminiClient < ClientBase
    API_BASE = "https://generativelanguage.googleapis.com"

    def call(prompt, max_tokens: 4096, temperature: 0.7)
      url = "#{API_BASE}/v1beta/models/#{model}:generateContent?key=#{api_key}"

      body = {
        contents: [{
          parts: [{
            text: prompt
          }]
        }],
        generationConfig: {
          temperature: temperature,
          maxOutputTokens: max_tokens,
          topP: 0.95,
          topK: 40
        }
      }

      headers = {
        'Content-Type' => 'application/json'
      }

      response = make_request(url, headers, body)

      if response.code == '200'
        data = JSON.parse(response.body, symbolize_names: true)

        # Extract text from response
        text = data.dig(:candidates, 0, :content, :parts, 0, :text) || ''

        # Get token usage
        input_tokens = data.dig(:usageMetadata, :promptTokenCount) || estimate_tokens(prompt)
        output_tokens = data.dig(:usageMetadata, :candidatesTokenCount) || estimate_tokens(text)

        {
          success: true,
          output: text.strip,
          model: model,
          provider: :gemini,
          tokens: {
            input: input_tokens,
            output: output_tokens,
            total: input_tokens + output_tokens
          }
        }
      else
        error_data = JSON.parse(response.body) rescue {}
        error_message = error_data.dig('error', 'message') || response.body

        {
          success: false,
          error: "Gemini API error (#{response.code}): #{error_message}",
          model: model,
          provider: :gemini
        }
      end
    rescue => e
      {
        success: false,
        error: "Gemini client error: #{e.message}",
        model: model,
        provider: :gemini
      }
    end
  end
end
