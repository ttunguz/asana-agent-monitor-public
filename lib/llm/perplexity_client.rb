# lib/llm/perplexity_client.rb
# Perplexity AI client (research-focused LLM with web search)

require_relative 'base_client'

module LLM
  class PerplexityClient < ClientBase
    API_BASE = "https://api.perplexity.ai"

    def call(prompt, max_tokens: 4096, temperature: 0.7)
      url = "#{API_BASE}/chat/completions"

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

        # Extract citations if available (Perplexity-specific feature)
        citations = data.dig(:citations) || []

        {
          success: true,
          output: text.strip,
          model: model,
          provider: :perplexity,
          citations: citations,
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
          error: "Perplexity API error (#{response.code}): #{error_message}",
          model: model,
          provider: :perplexity
        }
      end
    rescue => e
      {
        success: false,
        error: "Perplexity client error: #{e.message}",
        model: model,
        provider: :perplexity
      }
    end
  end
end
