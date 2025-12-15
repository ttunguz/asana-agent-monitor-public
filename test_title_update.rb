#!/usr/bin/env ruby
# Test script to verify task title update functionality

require_relative 'lib/agent_monitor'
require 'ostruct'

# Create a mock task
task = OpenStruct.new(
  gid: ENV['TEST_TASK_GID'] || '1234567890',  # Set TEST_TASK_GID env var to test with real task
  name: "Test task",
  notes: "Research acme.com for investment opportunities"
)

# Create a mock result
result = {
  success: true,
  comment: "✅ Claude Code Response:\n\nAcme Corp is a B2B SaaS company specializing in enterprise solutions."
}

# Initialize agent monitor (just to access methods)
agent = AgentMonitor.new

# Test title generation
puts "Testing title generation..."
puts "Original title: #{task.name}"
puts

new_title = agent.send(:generate_descriptive_title, task, result)
puts "Generated title: #{new_title}"
puts

if new_title && new_title != task.name && new_title.length > 5
  puts "✅ Title generation successful!"
  puts "   Length: #{new_title.length} chars"
  puts "   Cleaned: #{new_title == agent.send(:clean_title, new_title)}"
else
  puts "⚠️  Title generation skipped (no changes needed or title too short)"
end

puts "\nNote: To test actual Asana API update, set TEST_TASK_GID environment variable"
puts "      and ensure ASANA_API_KEY is configured."
