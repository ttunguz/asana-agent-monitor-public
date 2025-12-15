require 'net/http'
require 'json'
require 'uri'

task_gid = '1212293640555345'
url = URI("https://app.asana.com/api/1.0/tasks/#{task_gid}/stories?opt_fields=gid,text,created_at,created_by.name,type")

request = Net::HTTP::Get.new(url)
request["Authorization"] = "Bearer #{ENV['ASANA_API_KEY']}"
request["Accept"] = "application/json"

response = Net::HTTP.start(url.hostname, url.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
  http.request(request)
end

if response.code == '200'
  data = JSON.parse(response.body)
  comments = data['data'].select { |s| s['type'] == 'comment' }
  
  puts "Found #{comments.size} comments."
  comments.last(3).each do |comment|
    puts "\n--- Comment by #{comment.dig('created_by', 'name')} at #{comment['created_at']} ---"
    puts comment['text']
  end
else
  puts "Error: #{response.code} - #{response.body}"
end
