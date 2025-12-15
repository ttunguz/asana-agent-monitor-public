require_relative 'lib/agent_monitor'

monitor = AgentMonitor.new
comments = monitor.fetch_task_comments('1211645159742907')

puts "Comments for task 1211645159742907:"
comments.each do |c|
  puts "---"
  puts "Author: #{c[:created_by]}"
  puts "Date: #{c[:created_at]}"
  puts "Text: #{c[:text]}"
end
