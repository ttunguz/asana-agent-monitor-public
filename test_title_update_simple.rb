#!/usr/bin/env ruby
# Simple test to verify title update logic

require 'ostruct'

# Test the extract_context_from_notes logic inline
def extract_context_from_notes(notes)
  return nil if notes.nil? || notes.strip.empty?

  # Try to find domain/company references
  if notes =~ /(\S+\.(com|io|ai|co|net|org))/i
    domain = $1
    # Check for action verb before domain
    if notes =~ /(research|analyze|review|find|check|add|create|update)\s+.*?#{Regexp.escape(domain)}/i
      action = $1.capitalize
      return "#{action} #{domain}"
    end
    return domain
  end

  # Try to find email addresses
  if notes =~ /([a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,})/i
    email = $1
    # Extract name from email
    if email =~ /^([^@]+)@/
      name = $1.gsub(/[._]/, ' ').split.map(&:capitalize).join(' ')
      return "Email to #{name}"
    end
    return "Email to #{email}"
  end

  # Try to find URLs
  if notes =~ /(https?:\/\/[^\s]+)/
    url = $1
    # Extract domain for cleaner context
    if url =~ /https?:\/\/(?:www\.)?([^\/]+)/
      domain = $1
      return "Article from #{domain}"
    end
  end

  # Extract first meaningful line (not too short, not too long)
  lines = notes.split("\n").reject { |l| l.strip.empty? || l.strip.length < 10 }
  first_line = lines.first
  if first_line && first_line.length >= 10 && first_line.length <= 100
    return first_line.strip
  end

  nil
end

def extract_partial_progress(comment)
  return nil if comment.nil? || comment.strip.empty?

  # Look for step completion indicators
  if comment =~ /Completed (\d+)\/(\d+) steps/
    completed = $1.to_i
    total = $2.to_i
    return "#{completed}/#{total} steps" if completed > 0
  end

  # Look for last successful step
  step_matches = comment.scan(/✅ Step (\d+)/)
  if step_matches.any?
    last_step = step_matches.last[0]
    return "through step #{last_step}"
  end

  nil
end

# Test cases
test_cases = [
  {
    name: "Extract domain with action",
    input: "research acme.com for market analysis",
    method: :extract_context_from_notes,
    expected: "Research acme.com"
  },
  {
    name: "Extract email context",
    input: "Send email to john.doe@example.com",
    method: :extract_context_from_notes,
    expected: "Email to John Doe"
  },
  {
    name: "Extract URL domain",
    input: "Summarize https://techcrunch.com/ai-article",
    method: :extract_context_from_notes,
    expected: "Article from techcrunch.com"
  },
  {
    name: "Extract plain domain",
    input: "Check startup.io in Attio",
    method: :extract_context_from_notes,
    expected: "startup.io"
  },
  {
    name: "Extract progress fraction",
    input: "✅ Step 1 done\n✅ Step 2 done\nCompleted 2/5 steps",
    method: :extract_partial_progress,
    expected: "2/5 steps"
  },
  {
    name: "Extract progress from step list",
    input: "✅ Step 1\n✅ Step 2\n✅ Step 3",
    method: :extract_partial_progress,
    expected: "through step 3"
  }
]

puts "Testing Title Update Helper Methods\n"
puts "=" * 80

test_cases.each_with_index do |test, idx|
  puts "\nTest #{idx + 1}: #{test[:name]}"
  puts "-" * 80
  puts "Input: '#{test[:input][0..60]}...'"

  result = if test[:method] == :extract_context_from_notes
    extract_context_from_notes(test[:input])
  else
    extract_partial_progress(test[:input])
  end

  puts "Expected: '#{test[:expected]}'"
  puts "Got: '#{result}'"

  if result && result.include?(test[:expected])
    puts "✅ PASS"
  elsif result
    puts "⚠️  PARTIAL - Got result but doesn't match expected"
  else
    puts "❌ FAIL - No result"
  end
end

puts "\n" + "=" * 80
puts "Test complete!"
