require 'net/http'
require 'json'
require 'uri'
require_relative '../../config/agent_config'

module LLM
  class BaseClient
    def initialize(provider: nil, api_key: nil)
      @provider = provider || AgentConfig::AI_PROVIDER
      @api_key = api_key || get_api_key_for_provider(@provider)
    end

    def call(prompt, complexity: :standard)
      case @provider.downcase
      when 'gemini'
        gemini_call(prompt)
      when 'claude'
        claude_call(prompt)
      when 'openai'
        openai_call(prompt)
      when 'perplexity'
        perplexity_call(prompt)
      else
        { success: false, error: "Unsupported AI provider: #{@provider}" }
      end
    end

    private

    def get_api_key_for_provider(provider)
      key = case provider.downcase
            when 'gemini' then ENV['GEMINI_API_KEY']
            when 'claude' then ENV['CLAUDE_API_KEY']
            when 'openai' then ENV['OPENAI_API_KEY']
            when 'perplexity' then ENV['PERPLEXITY_API_KEY']
            end
            
      # Check config if env var is missing
      unless key
        config_path = ENV['AGENT_CONFIG'] || File.expand_path('../../config/config.yml', __FILE__)
        if File.exist?(config_path)
           require 'yaml'
           config = YAML.load_file(config_path)
           key = config.dig('ai', "#{provider.downcase}_api_key")
        end
      end
      
      key
    end

    def gemini_call(prompt)
      return { success: false, error: "Gemini API Key missing" } unless @api_key

      url = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=#{@api_key}")
      
      body = {
        contents: [{ parts: [{ text: prompt }] }]
      }

      response = execute_request(url, body)
      
      if response.code == '200'
        json = JSON.parse(response.body)
        text = json.dig('candidates', 0, 'content', 'parts', 0, 'text')
        { success: true, output: text, provider: :gemini }
      else
        { success: false, error: "Gemini API Error: #{response.code} - #{response.body}" }
      end
    end

    def claude_call(prompt)
      return { success: false, error: "Claude API Key missing" } unless @api_key

      url = URI("https://api.anthropic.com/v1/messages")
      
      body = {
        model: "claude-3-5-sonnet-20240620",
        max_tokens: 4096,
        messages: [{ role: "user", content: prompt }]
      }

      headers = {
        "x-api-key" => @api_key,
        "anthropic-version" => "2023-06-01"
      }

      response = execute_request(url, body, headers)
      
      if response.code == '200'
        json = JSON.parse(response.body)
        text = json.dig('content', 0, 'text')
        { success: true, output: text, provider: :claude }
      else
        { success: false, error: "Claude API Error: #{response.code} - #{response.body}" }
      end
    end

    def openai_call(prompt)
      return { success: false, error: "OpenAI API Key missing" } unless @api_key

      url = URI("https://api.openai.com/v1/chat/completions")
      
      body = {
        model: "gpt-4o",
        messages: [{ role: "user", content: prompt }]
      }

      headers = { "Authorization" => "Bearer #{@api_key}" }

      response = execute_request(url, body, headers)
      
      if response.code == '200'
        json = JSON.parse(response.body)
        text = json.dig('choices', 0, 'message', 'content')
        { success: true, output: text, provider: :openai }
      else
        { success: false, error: "OpenAI API Error: #{response.code} - #{response.body}" }
      end
    end

    def perplexity_call(prompt)
      return { success: false, error: "Perplexity API Key missing" } unless @api_key

      url = URI("https://api.perplexity.ai/chat/completions")
      
      body = {
        model: "llama-3.1-sonar-large-128k-online",
        messages: [{ role: "user", content: prompt }]
      }

      headers = { "Authorization" => "Bearer #{@api_key}" }

      response = execute_request(url, body, headers)
      
      if response.code == '200'
        json = JSON.parse(response.body)
        text = json.dig('choices', 0, 'message', 'content')
        { success: true, output: text, provider: :perplexity }
      else
        { success: false, error: "Perplexity API Error: #{response.code} - #{response.body}" }
      end
    end

    def execute_request(url, body, headers = {})
      http = Net::HTTP.new(url.hostname, url.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(url)
      request["Content-Type"] = "application/json"
      
      headers.each { |k, v| request[k] = v }
      
      request.body = body.to_json
      
      http.request(request)
    rescue => e
      OpenStruct.new(code: '0', body: e.message)
    end
  end
end