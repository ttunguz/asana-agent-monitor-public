#!/usr/bin/env ruby
# test_dpsy.rb
# Test script for DPSY (Dynamic Prompt System)

require 'ostruct'
require_relative 'lib/task_classifier'
require_relative 'lib/conversation_summarizer'
require_relative 'lib/prompt_templates/simple_query'
require_relative 'lib/prompt_templates/email'
require_relative 'lib/prompt_templates/company_research'
require_relative 'lib/prompt_templates/general'

# Test 1: Simple Query Classification
puts "=" * 60
puts "Test 1: Simple Query Task"
puts "=" * 60

task1 = OpenStruct.new(
  gid: "test-1",
  name: "What's the weather in San Francisco?",
  notes: ""
)

type1 = TaskClassifier.classify(task1)
puts "Task: #{task1.name}"
puts "Classified as: :#{type1}"
puts "Expected: :simple_query"
puts "✅ PASS" if type1 == :simple_query

template1 = PromptTemplates::SimpleQuery.new(task: task1, comments: [])
prompt1 = template1.build

puts "\nPrompt length: #{prompt1.length} chars"
puts "Prompt preview:"
puts prompt1[0..200]
puts "\nIncludes API docs? #{prompt1.include?('CODE MODE API')}"
puts "✅ PASS - No API docs" unless prompt1.include?('CODE MODE API')

# Test 2: Email Task Classification
puts "\n" + "=" * 60
puts "Test 2: Email Task"
puts "=" * 60

task2 = OpenStruct.new(
  gid: "test-2",
  name: "Draft email to Art about Q4 board meeting",
  notes: "Include agenda items: financials, hiring update, portfolio review"
)

type2 = TaskClassifier.classify(task2)
puts "Task: #{task2.name}"
puts "Classified as: :#{type2}"
puts "Expected: :email"
puts "✅ PASS" if type2 == :email

template2 = PromptTemplates::Email.new(task: task2, comments: [])
prompt2 = template2.build

puts "\nPrompt length: #{prompt2.length} chars"
puts "Includes EmailAPI docs? #{prompt2.include?('EmailAPI')}"
puts "✅ PASS - Has EmailAPI docs" if prompt2.include?('EmailAPI')
puts "Includes AttioAPI docs? #{prompt2.include?('AttioAPI')}"
puts "✅ PASS - No AttioAPI docs" unless prompt2.include?('AttioAPI')

# Test 3: Company Research Classification
puts "\n" + "=" * 60
puts "Test 3: Company Research Task"
puts "=" * 60

task3 = OpenStruct.new(
  gid: "test-3",
  name: "Research acme.com and add to Attio if VCBench score > 40%",
  notes: ""
)

type3 = TaskClassifier.classify(task3)
puts "Task: #{task3.name}"
puts "Classified as: :#{type3}"
puts "Expected: :company_research"
puts "✅ PASS" if type3 == :company_research

template3 = PromptTemplates::CompanyResearch.new(task: task3, comments: [])
prompt3 = template3.build

puts "\nPrompt length: #{prompt3.length} chars"
puts "Includes AttioAPI docs? #{prompt3.include?('AttioAPI')}"
puts "✅ PASS - Has AttioAPI docs" if prompt3.include?('AttioAPI')
puts "Includes ResearchAPI docs? #{prompt3.include?('ResearchAPI')}"
puts "✅ PASS - Has ResearchAPI docs" if prompt3.include?('ResearchAPI')
puts "Includes EmailAPI docs? #{prompt3.include?('EmailAPI')}"
puts "✅ PASS - No EmailAPI docs" unless prompt3.include?('EmailAPI')

# Test 4: Conversation History Summarization
puts "\n" + "=" * 60
puts "Test 4: Conversation History Summarization"
puts "=" * 60

# Create 10 long comments (simulating a long conversation)
long_comments = 10.times.map do |i|
  {
    gid: "comment-#{i}",
    text: "This is a long comment about company research. " * 50, # ~2500 chars each
    created_by: "Tom Tunguz",
    created_at: (Time.now - (10 - i) * 3600).iso8601
  }
end

puts "Original comments: #{long_comments.size}"
puts "Total chars: #{long_comments.sum { |c| c[:text].length }}"

summarized = ConversationSummarizer.summarize_if_needed(long_comments)
puts "Summarized comments: #{summarized.size}"
puts "✅ PASS - History summarized" if summarized.size < long_comments.size

if summarized.size < long_comments.size
  puts "\nSummary comment:"
  puts summarized.first[:text]
end

# Test 5: Token Reduction Comparison
puts "\n" + "=" * 60
puts "Test 5: Token Reduction Analysis"
puts "=" * 60

# Simulate old system (full API docs for simple query)
old_system_prompt = <<~OLD
Task : What's the weather in San Francisco?

IMPORTANT INSTRUCTIONS:

1. CODE MODE APIs (REQUIRED):
   - EmailAPI : search, read, send, reply, archive emails
   - AttioAPI : find, create, update companies & deals in CRM
   - TaskAPI : create, list, search, complete Asana tasks
   - ResearchAPI : quick_lookup, harmonic_company, vcbench_analyze
   - CalendarAPI : create events, schedule meetings

    def email_instructions
      <<~INSTRUCTIONS
      EMAIL API:
         - EmailAPI.search(from: 'sender@domain.com', limit: 3, format: :concise)
         - EmailAPI.send(to: 'recipient@domain.com', subject: '...', body: '...')

         Usage: require_relative '/Users/tomasztunguz/.gemini/code_mode/email_api'
      INSTRUCTIONS
    end

2. SAFETY:
   - DO NOT run 'find' on entire home directory - causes system hangs

3. EMAIL ENCODING:
   - Use 'notmuch show --format=json' for structured output
OLD

puts "Old system (simple query with full docs):"
puts "  Prompt length: #{old_system_prompt.length} chars"

puts "\nNew system (DPSY with SimpleQueryTemplate):"
puts "  Prompt length: #{prompt1.length} chars"

reduction = ((old_system_prompt.length - prompt1.length).to_f / old_system_prompt.length * 100).round(1)
puts "\nToken reduction: #{reduction}%"
puts "✅ PASS - Significant token reduction" if reduction > 50

puts "\n" + "=" * 60
puts "All Tests Complete!"
puts "=" * 60
