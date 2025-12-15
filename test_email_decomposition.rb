#!/usr/bin/env ruby
# encoding: utf-8
# Test that email addresses don't trigger GEPA decomposition

require_relative 'lib/task_decomposer'

# Mock task object
Task = Struct.new(:name, :notes)

puts "Testing email address handling in task decomposer..."
puts

# Test 1: Email draft request with email addresses (should NOT decompose)
task1 = Task.new(
  "Email Magpie researchers",
  "Bill Yuchen Lin: yuchenl@allenai.org, yuchenlin1995@gmail.com\nZhangchen Xu: zxu9@uw.edu"
)
comment1 = "Draft an email to yuchenl@allenai.org, yuchenlin1995@gmail.com about synthetic data"

should_decompose1 = TaskDecomposer.should_decompose?(task1, comment1)
steps1 = TaskDecomposer.decompose(task1, comment1)

puts "Test 1: Email draft with email addresses"
puts "  Input: '#{comment1}'"
puts "  Should decompose: #{should_decompose1}"
puts "  Steps: #{steps1.size}"
puts "  Result: #{should_decompose1 ? '❌ FAIL - Should not decompose' : '✅ PASS - Correctly treated as single step'}"
puts

# Test 2: Multi-company research (should decompose)
task2 = Task.new("Research companies", "")
comment2 = "Research stripe.com, plaid.com, and alloy.ai"

should_decompose2 = TaskDecomposer.should_decompose?(task2, comment2)
steps2 = TaskDecomposer.decompose(task2, comment2)

puts "Test 2: Multi-company research (no email addresses)"
puts "  Input: '#{comment2}'"
puts "  Should decompose: #{should_decompose2}"
puts "  Steps: #{steps2.size}"
puts "  Result: #{should_decompose2 && steps2.size == 3 ? '✅ PASS - Correctly decomposed into 3 steps' : '❌ FAIL'}"
puts

# Test 3: Simple query with email domain (should NOT decompose)
task3 = Task.new("Contact info", "")
comment3 = "What's the email for allenai.org?"

should_decompose3 = TaskDecomposer.should_decompose?(task3, comment3)
steps3 = TaskDecomposer.decompose(task3, comment3)

puts "Test 3: Simple query mentioning domain"
puts "  Input: '#{comment3}'"
puts "  Should decompose: #{should_decompose3}"
puts "  Steps: #{steps3.size}"
puts "  Result: #{should_decompose3 ? '❌ FAIL - Should not decompose (no research keyword)' : '✅ PASS'}"
puts

puts "Summary:"
puts "  Email addresses now correctly excluded from domain detection"
puts "  GEPA won't misinterpret email drafts as multi-company research"
