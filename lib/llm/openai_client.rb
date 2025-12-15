# lib/llm/openai_client.rb
# OpenAI GPT client

require_relative 'base_client'

module LLM
  class OpenAIClient < ClientBase
    API_BASE = "https://api.openai.com"

    def call(prompt, max_tokens: 4096, temperature: 0.7)
      url = "#{API_BASE}/v1/chat/completions"

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
        'Authorization' => "Bearer #{api_key}"
      }

      response = make_request(url, headers, body)

      if response.code == '200'
        data = JSON.parse(response.body, symbolize_names: true)

        # Extract text from response
        text = data.dig(:choices, 0, :message, :content) || ''

        # Get token usage
        input_tokens = data.dig(:usage, :prompt_tokens) || estimate_tokens(prompt)
        output_tokens = data.dig(:usage, :completion_tokens) || estimate_tokens(text)

        {
          success: true,
          output: text.strip,
          model: model,
          provider: :openai,
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
          error: "OpenAI API error (#{response.code}): #{error_message}",
          model: model,
          provider: :openai
        }
      end
    rescue => e
      {
        success: false,
        error: "OpenAI client error: #{e.message}",
        model: model,
        provider: :openai
      }
    end
  end
end
