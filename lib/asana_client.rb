require 'net/http'
require 'json'
require 'uri'
require 'openssl'
require_relative '../config/agent_config'

module AsanaClient
  def self.add_comment(task_id:, comment:)
    url = "https://app.asana.com/api/1.0/tasks/#{task_id}/stories"
    body = { data: { text: comment } }
    
    response = execute_request(url, method: :post, body: body)
    
    if response.code == '201'
      { success: true, data: JSON.parse(response.body) }
    else
      { success: false, error: "Asana API Error: #{response.code} - #{response.body}" }
    end
  end

  def self.complete_task(task_id:)
    url = "https://app.asana.com/api/1.0/tasks/#{task_id}"
    body = { data: { completed: true } }
    
    response = execute_request(url, method: :put, body: body)
    
    if response.code == '200'
      { success: true }
    else
      { success: false, error: "Asana API Error: #{response.code} - #{response.body}" }
    end
  end

  def self.create_task(title:, notes: '', assignee: nil, due_on: nil, project_gid: nil)
    url = "https://app.asana.com/api/1.0/tasks"
    
    data = {
      name: title,
      notes: notes,
      workspace: AgentConfig::ASANA_WORKSPACE_GID
    }
    
    data[:assignee] = assignee if assignee
    data[:due_on] = due_on if due_on
    data[:projects] = [project_gid] if project_gid

    body = { data: data }
    
    response = execute_request(url, method: :post, body: body)
    
    if response.code == '201'
      json = JSON.parse(response.body)
      { success: true, gid: json.dig('data', 'gid') }
    else
      { success: false, error: "Asana API Error: #{response.code} - #{response.body}" }
    end
  end

  def self.update_task_title(task_id, new_title)
    url = "https://app.asana.com/api/1.0/tasks/#{task_id}"
    body = { data: { name: new_title } }
    
    response = execute_request(url, method: :put, body: body)
    
    if response.code == '200'
      { success: true }
    else
      raise "Asana API Error: #{response.code} - #{response.body}"
    end
  end

  def self.fetch_task_stories(task_id)
    url = "https://app.asana.com/api/1.0/tasks/#{task_id}/stories?opt_fields=gid,text,created_at,created_by.name,type"
    response = execute_request(url)
    
    return [] unless response.code == '200'
    
    data = JSON.parse(response.body, symbolize_names: true)
    data[:data]
  end

  def self.fetch_tasks(project_gid, completed_since: 'now')
    url = "https://app.asana.com/api/1.0/projects/#{project_gid}/tasks?opt_fields=name,notes,gid,completed&completed_since=#{completed_since}&limit=100"
    response = execute_request(url)
    
    return [] unless response.code == '200'
    
    data = JSON.parse(response.body, symbolize_names: true)
    data[:data]
  end

  # Private helper for HTTP requests
  def self.execute_request(url_string, method: :get, body: nil, max_retries: 3)
    url = URI(url_string)
    retries = 0

    begin
      http = Net::HTTP.new(url.hostname, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = 10
      http.read_timeout = 30

      request = case method
                when :post
                  Net::HTTP::Post.new(url)
                when :put
                  Net::HTTP::Put.new(url)
                else
                  Net::HTTP::Get.new(url)
                end

      # Get API Key from AgentConfig or ENV
      api_key = AgentConfig::ASANA_API_KEY rescue ENV['ASANA_API_KEY'] # Fallback if AgentConfig const missing
      unless api_key
        # Check config hash if constant not defined yet (during init)
        config_path = ENV['AGENT_CONFIG'] || File.expand_path('../../config/config.yml', __FILE__)
        if File.exist?(config_path)
           require 'yaml'
           config = YAML.load_file(config_path)
           api_key = config.dig('asana', 'api_key')
        end
      end
      
      # Final check for env var
      api_key ||= ENV['ASANA_API_KEY']
      
      raise "ASANA_API_KEY not found" unless api_key

      request["Authorization"] = "Bearer #{api_key}"
      request["Accept"] = "application/json"
      request["Content-Type"] = "application/json" if body
      request.body = body.to_json if body

      response = http.request(request)

      # Handle Rate Limiting (429)
      if response.code == '429'
        retry_after = response['Retry-After']&.to_i || 60
        puts "[AsanaClient] Rate Limit 429. Waiting #{retry_after}s..."
        sleep(retry_after)
        raise "Rate Limit 429"
      end

      # Handle Server Errors (5xx)
      if response.code.start_with?('5')
        raise "Server Error #{response.code}"
      end

      response

    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ETIMEDOUT, SocketError => e
      retries += 1
      if retries <= max_retries
        sleep_time = 2 ** retries
        puts "[AsanaClient] Network Error (#{e.class}). Retrying in #{sleep_time}s..."
        sleep(sleep_time)
        retry
      else
        puts "[AsanaClient] Request failed after #{max_retries} retries"
        OpenStruct.new(code: '0', body: e.message) # Fake response object
      end
    rescue => e
      retries += 1
      if retries <= max_retries
        sleep_time = 2 ** retries
        puts "[AsanaClient] Error (#{e.message}). Retrying in #{sleep_time}s..."
        sleep(sleep_time)
        retry
      else
        puts "[AsanaClient] Failed: #{e.message}"
        OpenStruct.new(code: '0', body: e.message)
      end
    end
  end
end
