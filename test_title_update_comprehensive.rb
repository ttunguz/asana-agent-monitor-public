#!/usr/bin/env ruby
# Test comprehensive title update functionality

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'agent_monitor'
require 'ostruct'

# Mock task & result scenarios
test_cases = [
  {
    name: "Timeout with context in notes",
    task: OpenStruct.new(
      gid: "test_1",
      name: "Task",
      notes: "Research acme.com for market analysis"
    ),
    result: {
      success: false,
      error: "Workflow timeout after 30 minutes",
      comment: ""
    },
    expected_prefix: "⏱️ Timeout"
  },
  {
    name: "Timeout with partial GEPA progress",
    task: OpenStruct.new(
      gid: "test_2",
      name: "Research Company",
      notes: "Analyze startup.io using VCBench"
    ),
    result: {
      success: false,
      error: "timeout",
      comment: "✅ Step 1/3 completed\n✅ Step 2/3 completed\nCompleted 2/3 steps"
    },
    expected_prefix: "⏱️ Timeout (2/3 steps)"
  },
  {
    name: "General error with domain",
    task: OpenStruct.new(
      gid: "test_3",
      name: "Task",
      notes: "Add company example.com to Attio"
    ),
    result: {
      success: false,
      error: "API Error: Rate limit exceeded",
      comment: ""
    },
    expected_prefix: "❌"
  },
  {
    name: "Success with email workflow",
    task: OpenStruct.new(
      gid: "test_4",
      name: "Draft email",
      notes: "Write email to john@example.com about meeting"
    ),
    result: {
      success: true,
      error: "",
      comment: "Subject: Meeting Follow-up\nTo: john@example.com"
    },
    expected_prefix: "Email"
  },
  {
    name: "Success with market map",
    task: OpenStruct.new(
      gid: "test_5",
      name: "Create map",
      notes: "market map for AI infrastructure startups"
    ),
    result: {
      success: true,
      error: "",
      comment: "Market map created successfully"
    },
    expected_prefix: "Market Map"
  },
  {
    name: "Generic title with meaningful notes",
    task: OpenStruct.new(
      gid: "test_6",
      name: "Task",
      notes: "Summarize this article about cloud computing trends: https://example.com/article"
    ),
    result: {
      success: true,
      error: "",
      comment: "Article summarized successfully"
    },
    expected_prefix: "Summary"
  }
]

# Create mock monitor instance to test title generation
class MockMonitor < AgentMonitor
  def initialize
    # Skip normal initialization
  end

  # Expose private methods for testing
  public :generate_descriptive_title, :extract_context_from_notes, :extract_title_from_workflow,
         :extract_first_meaningful_phrase, :clean_title, :extract_partial_progress

  # Override log to suppress output
  def log(message, level = :info)
    # Silent
  end
end

monitor = MockMonitor.new

puts "Testing Title Update Logic\n"
puts "=" * 80

test_cases.each_with_index do |test, idx|
  puts "\nTest #{idx + 1}: #{test[:name]}"
  puts "-" * 80

  new_title = monitor.generate_descriptive_title(test[:task], test[:result])

  puts "Original title: '#{test[:task].name}'"
  puts "Task notes: '#{test[:task].notes[0..60]}...'"
  puts "Result success: #{test[:result][:success]}"
  puts "Result error: '#{test[:result][:error]}'"
  puts "\nGenerated title: '#{new_title}'"

  # Check if title matches expected pattern
  if new_title && new_title.include?(test[:expected_prefix])
    puts "✅ PASS - Title contains expected prefix '#{test[:expected_prefix]}'"
  elsif new_title
    puts "⚠️  PARTIAL - Generated title but missing expected prefix '#{test[:expected_prefix]}'"
  else
    puts "❌ FAIL - No title generated"
  end
end

puts "\n" + "=" * 80
puts "Testing helper methods"
puts "=" * 80

# Test extract_context_from_notes
puts "\n1. extract_context_from_notes:"
test_notes = [
  "research startup.com for market analysis",
  "Send email to founder@example.com about partnership",
  "Analyze this article: https://techcrunch.com/ai-trends",
  "Create task for reviewing pitch deck"
]

test_notes.each do |note|
  context = monitor.extract_context_from_notes(note)
  puts "  Note: '#{note[0..50]}...'"
  puts "  Context: '#{context}'"
  puts
end

# Test extract_partial_progress
puts "\n2. extract_partial_progress:"
test_comments = [
  "✅ Step 1/5 completed\n✅ Step 2/5 completed\nCompleted 2/5 steps",
  "✅ Step 1 completed\n✅ Step 2 completed\n✅ Step 3 completed",
  "No steps completed yet"
]

test_comments.each do |comment|
  progress = monitor.extract_partial_progress(comment)
  puts "  Comment: '#{comment[0..50]}...'"
  puts "  Progress: '#{progress || 'none'}'"
  puts
end

puts "\nTest complete!"
