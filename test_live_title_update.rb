#!/usr/bin/env ruby
# Live test for task title update via direct Asana API
#
# Usage:
#   export TEST_TASK_GID="your_task_gid"
#   export ASANA_API_KEY="your_api_key"
#   ruby test_live_title_update.rb

require_relative 'lib/agent_monitor'
require 'ostruct'

# Check for required environment variables
unless ENV['ASANA_API_KEY']
  puts "❌ Error: ASANA_API_KEY environment variable not set"
  exit 1
end

unless ENV['TEST_TASK_GID']
  puts "❌ Error: TEST_TASK_GID environment variable not set"
  puts "\nUsage:"
  puts "  export TEST_TASK_GID='your_task_gid_here'"
  puts "  export ASANA_API_KEY='your_api_key'"
  puts "  ruby test_live_title_update.rb"
  exit 1
end

task_gid = ENV['TEST_TASK_GID']
puts "Testing live title update for task: #{task_gid}"
puts

# Fetch current task details first
require 'net/http'
require 'json'
require 'uri'

url = URI("https://app.asana.com/api/1.0/tasks/#{task_gid}?opt_fields=name,notes,assignee.name")
request = Net::HTTP::Get.new(url)
request["Authorization"] = "Bearer #{ENV['ASANA_API_KEY']}"

puts "Fetching current task details..."
response = Net::HTTP.start(url.hostname, url.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
  http.request(request)
end

if response.code != '200'
  puts "❌ Failed to fetch task: #{response.code}"
  puts response.body
  exit 1
end

task_data = JSON.parse(response.body, symbolize_names: true)[:data]
current_title = task_data[:name]
assignee_name = task_data.dig(:assignee, :name) || 'Unassigned'

puts "Current title: #{current_title}"
puts "Assignee: #{assignee_name}"
puts "Task notes: #{task_data[:notes]&.slice(0, 100)}..."
puts

# Create a mock task object
task = OpenStruct.new(
  gid: task_gid,
  name: current_title,
  notes: task_data[:notes] || ""
)

# Create a mock result
result = {
  success: true,
  comment: "✅ Claude Code Response:\n\nTest update for title enhancement feature."
}

# Initialize agent monitor
agent = AgentMonitor.new
puts

# Generate new title
puts "Generating new descriptive title..."
new_title = agent.send(:generate_descriptive_title, task, result)

if new_title.nil?
  puts "⚠️  No title update needed (current title is already descriptive)"
  exit 0
end

if new_title == current_title
  puts "⚠️  Generated title is same as current title"
  exit 0
end

if new_title.length <= 5
  puts "⚠️  Generated title too short: '#{new_title}'"
  exit 0
end

puts "New title: #{new_title}"
puts

# Ask for confirmation
print "Update task title? (y/n): "
confirmation = gets.chomp.downcase

unless confirmation == 'y' || confirmation == 'yes'
  puts "❌ Update cancelled"
  exit 0
end

# Perform live update
puts "\nUpdating task title via Asana API..."
begin
  agent.send(:update_task_title_direct, task_gid, new_title)
  puts "✅ Title updated successfully!"
  puts
  puts "Verification:"
  puts "  Old title: #{current_title}"
  puts "  New title: #{new_title}"
rescue => e
  puts "❌ Failed to update title: #{e.message}"
  exit 1
end
