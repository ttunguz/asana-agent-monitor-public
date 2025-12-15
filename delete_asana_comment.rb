require 'net/http'
require 'json'
require 'uri'

TASK_GID = '1212057493748932'
TARGET_TEXT = 'fix the SSL issue'

def fetch_comments(task_gid)
  url = URI("https://app.asana.com/api/1.0/tasks/#{task_gid}/stories?opt_fields=gid,text,created_by.name,type")
  request = Net::HTTP::Get.new(url)
  request["Authorization"] = "Bearer #{ENV['ASANA_API_KEY']}"
  request["Accept"] = "application/json"

  response = Net::HTTP.start(url.hostname, url.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
    http.request(request)
  end

  if response.code == '200'
    JSON.parse(response.body)['data']
  else
    puts "Error fetching comments: #{response.code} - #{response.body}"
    []
  end
end

def delete_comment(comment_gid)
  url = URI("https://app.asana.com/api/1.0/stories/#{comment_gid}")
  request = Net::HTTP::Delete.new(url)
  request["Authorization"] = "Bearer #{ENV['ASANA_API_KEY']}"
  request["Accept"] = "application/json"

  response = Net::HTTP.start(url.hostname, url.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
    http.request(request)
  end

  if response.code == '200'
    puts "Successfully deleted comment #{comment_gid}"
  else
    puts "Error deleting comment #{comment_gid}: #{response.code} - #{response.body}"
  end
end

puts "Fetching comments for task #{TASK_GID}..."
comments = fetch_comments(TASK_GID)

target_comment = comments.find do |c|
  c['type'] == 'comment' && c['text'] && c['text'].include?(TARGET_TEXT)
end

if target_comment
  puts "Found target comment:"
  puts "GID: #{target_comment['gid']}"
  puts "Text: #{target_comment['text']}"
  puts "Author: #{target_comment.dig('created_by', 'name')}"
  
  puts "Deleting..."
  delete_comment(target_comment['gid'])
else
  puts "Target comment '#{TARGET_TEXT}' not found."
  puts "Available comments:"
  comments.select { |c| c['type'] == 'comment' }.each do |c|
    puts "- [#{c['gid']}] #{c['text'][0..50]}..."
  end
end
