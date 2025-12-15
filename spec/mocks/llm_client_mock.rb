# spec/mocks/llm_client_mock.rb

module LLM
  class BaseClient
    def initialize(provider: nil, api_key: nil)
      @provider = provider || 'mock'
    end

    def call(prompt, complexity: :standard)
      # Check for predefined responses
      response = LLMClientMock.get_response(prompt)
      
      if response
        { success: true, output: response, provider: @provider }
      else
        # Default fallback response
        { 
          success: true, 
          output: "Mock AI Response for: #{prompt[0..50]}...", 
          provider: @provider 
        }
      end
    end
  end
end

module LLMClientMock
  def self.reset!
    @responses = {}
    @requests = []
  end

  def self.mock_response(prompt_pattern, response_text)
    @responses[prompt_pattern] = response_text
  end

  def self.get_response(prompt)
    @requests << prompt
    @responses.each do |pattern, response|
      return response if prompt.match?(pattern)
    end
    nil
  end
  
  def self.requests
    @requests
  end
end
