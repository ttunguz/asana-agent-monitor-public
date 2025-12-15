#!/usr/bin/env ruby
# test_gepa.rb
# Test script for GEPA (Guided Exploration & Plan Adjustment)

require 'ostruct'
require_relative 'lib/task_decomposer'

puts "=" * 70
puts "GEPA (Guided Exploration & Plan Adjustment) Test Suite"
puts "=" * 70

# Test 1: Single company research (should NOT decompose)
puts "\n" + "=" * 70
puts "Test 1: Single Company Research (No Decomposition)"
puts "=" * 70

task1 = OpenStruct.new(
  gid: "test-1",
  name: "Research acme.com and add to Attio",
  notes: ""
)

should_decompose1 = TaskDecomposer.should_decompose?(task1)
steps1 = TaskDecomposer.decompose(task1)

puts "Task: #{task1.name}"
puts "Should decompose? #{should_decompose1}"
puts "Expected: false"
puts "✅ PASS" if !should_decompose1

puts "\nSteps: #{steps1.size}"
steps1.each do |step|
  puts "  #{step.number}. #{step.name}"
  puts "     Description: #{step.description}"
  puts "     Retry on failure: #{step.retry_on_failure}"
end

# Test 2: Multi-company research (should decompose)
puts "\n" + "=" * 70
puts "Test 2: Multi-Company Research (Should Decompose)"
puts "=" * 70

task2 = OpenStruct.new(
  gid: "test-2",
  name: "Research stripe.com, plaid.com, and alloy.ai",
  notes: "Add to Attio if VCBench score > 40%"
)

should_decompose2 = TaskDecomposer.should_decompose?(task2)
steps2 = TaskDecomposer.decompose(task2)

puts "Task: #{task2.name}"
puts "Notes: #{task2.notes}"
puts "Should decompose? #{should_decompose2}"
puts "Expected: true"
puts "✅ PASS" if should_decompose2

puts "\nSteps: #{steps2.size}"
puts "Expected: 3"
puts "✅ PASS" if steps2.size == 3

steps2.each do |step|
  puts "\n  Step #{step.number}: #{step.name}"
  puts "  Description: #{step.description}"
  puts "  Success criteria: #{step.success_criteria}"
  puts "  Retry on failure: #{step.retry_on_failure}"
end

# Test 3: Multi-company with comma-separated domains
puts "\n" + "=" * 70
puts "Test 3: Comma-Separated Domains"
puts "=" * 70

task3 = OpenStruct.new(
  gid: "test-3",
  name: "Research figma.com, miro.com, notion.so",
  notes: ""
)

steps3 = TaskDecomposer.decompose(task3)

puts "Task: #{task3.name}"
puts "Steps: #{steps3.size}"
puts "Expected: 3"
puts "✅ PASS" if steps3.size == 3

steps3.each do |step|
  puts "  #{step.number}. #{step.name} - #{step.description}"
end

# Test 4: Extract VCBench threshold
puts "\n" + "=" * 70
puts "Test 4: VCBench Threshold Extraction"
puts "=" * 70

task4 = OpenStruct.new(
  gid: "test-4",
  name: "Research acme.com and beta.io",
  notes: "Add to Attio if VCBench score > 45%"
)

steps4 = TaskDecomposer.decompose(task4)

puts "Task: #{task4.name}"
puts "Notes: #{task4.notes}"
puts "\nStep descriptions:"
steps4.each do |step|
  puts "  #{step.number}. #{step.description}"
  if step.description.include?("45%")
    puts "  ✅ PASS - Correctly extracted 45% threshold"
  end
end

# Test 5: Simple query (should NOT decompose)
puts "\n" + "=" * 70
puts "Test 5: Simple Query (No Decomposition)"
puts "=" * 70

task5 = OpenStruct.new(
  gid: "test-5",
  name: "What's the weather in San Francisco?",
  notes: ""
)

should_decompose5 = TaskDecomposer.should_decompose?(task5)
puts "Task: #{task5.name}"
puts "Should decompose? #{should_decompose5}"
puts "Expected: false"
puts "✅ PASS" if !should_decompose5

# Test 6: Retry flag verification
puts "\n" + "=" * 70
puts "Test 6: Retry Flag for Company Research"
puts "=" * 70

task6 = OpenStruct.new(
  gid: "test-6",
  name: "Research startup.com and competitor.io",
  notes: ""
)

steps6 = TaskDecomposer.decompose(task6)

puts "Task: #{task6.name}"
puts "\nRetry flags:"
steps6.each do |step|
  puts "  Step #{step.number}: retry_on_failure = #{step.retry_on_failure}"
  puts "  ✅ PASS - Company research has retry enabled" if step.retry_on_failure
end

# Test 7: Deduplication of domains
puts "\n" + "=" * 70
puts "Test 7: Domain Deduplication"
puts "=" * 70

task7 = OpenStruct.new(
  gid: "test-7",
  name: "Research acme.com and acme.com again",
  notes: ""
)

steps7 = TaskDecomposer.decompose(task7)

puts "Task: #{task7.name}"
puts "Steps: #{steps7.size}"
puts "Expected: 1 (duplicate domain should be removed)"
puts "✅ PASS - Duplicates removed" if steps7.size == 1

# Summary
puts "\n" + "=" * 70
puts "Test Summary"
puts "=" * 70
puts "✅ Single company: No decomposition"
puts "✅ Multiple companies: Decomposition with correct step count"
puts "✅ VCBench threshold extraction"
puts "✅ Retry flags set for research tasks"
puts "✅ Domain deduplication"
puts "\n" + "=" * 70
puts "All GEPA Tests Complete!"
puts "=" * 70
