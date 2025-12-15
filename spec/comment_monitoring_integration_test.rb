#!/usr/bin/env ruby
# spec/comment_monitoring_integration_test.rb

require_relative '../lib/comment_tracker'
require_relative '../lib/workflow_router'
require_relative '../lib/workflows/base'
require_relative '../config/agent_config'

puts "=" * 60
puts "Comment Monitoring Integration Tests"
puts "=" * 60

# Test 1: CommentTracker integration
puts "\n✓ Test 1: CommentTracker loads with config"
tracker = CommentTracker.new(AgentConfig::COMMENT_STATE_FILE)
puts "  PASS: CommentTracker initialized with config file"

# Test 2: WorkflowRouter route_from_comment method exists
puts "\n✓ Test 2: WorkflowRouter.route_from_comment exists"
router = WorkflowRouter.new
raise "FAIL: route_from_comment method not found" unless router.respond_to?(:route_from_comment)
puts "  PASS: route_from_comment method exists"

# Test 3: Route from comment with keyword
puts "\n✓ Test 3: Route from comment with 'research' keyword"
require 'ostruct'
mock_task = OpenStruct.new(name: "Test Task", notes: "", gid: "12345")
workflow = router.route_from_comment("Please research acme.com", mock_task)
raise "FAIL: Expected CompanyResearch workflow" unless workflow.is_a?(Workflows::CompanyResearch)
puts "  PASS: Routed 'research' keyword to CompanyResearch"

# Test 4: Route from comment with URL
puts "\n✓ Test 4: Route from comment with URL"
workflow = router.route_from_comment("Check out thehog.ai", mock_task)
raise "FAIL: Expected CompanyResearch workflow for homepage" unless workflow.is_a?(Workflows::CompanyResearch)
puts "  PASS: Routed homepage URL to CompanyResearch"

# Test 5: Route from comment with article URL
puts "\n✓ Test 5: Route from comment with article URL"
workflow = router.route_from_comment("Read https://example.com/blog/post", mock_task)
raise "FAIL: Expected ArticleSummary workflow" unless workflow.is_a?(Workflows::ArticleSummary)
puts "  PASS: Routed article URL to ArticleSummary"

# Test 6: Workflow triggered_by context
puts "\n✓ Test 6: Workflow knows it was triggered by comment"
workflow = router.route_from_comment("research startup.com", mock_task)
raise "FAIL: Expected triggered_by == :comment" unless workflow.triggered_by == :comment
raise "FAIL: Expected from_comment? == true" unless workflow.from_comment?
puts "  PASS: Workflow has correct triggered_by context"

# Test 7: Comment monitoring configuration
puts "\n✓ Test 7: Comment monitoring configuration loaded"
raise "FAIL: ENABLE_COMMENT_MONITORING not set" unless AgentConfig.const_defined?(:ENABLE_COMMENT_MONITORING)
raise "FAIL: COMMENT_STATE_FILE not set" unless AgentConfig.const_defined?(:COMMENT_STATE_FILE)
puts "  PASS: Comment monitoring config exists"
puts "  - Enabled: #{AgentConfig::ENABLE_COMMENT_MONITORING}"
puts "  - State file: #{AgentConfig::COMMENT_STATE_FILE}"

# Test 8: URL extraction from comments
puts "\n✓ Test 8: URL extraction from comment text"
workflow = router.route_from_comment("Can you research stripe.com and plaid.com?", mock_task)
raise "FAIL: Expected to extract first URL" unless workflow.is_a?(Workflows::CompanyResearch)
puts "  PASS: Extracted URL from comment text"

# Test 9: No workflow match returns nil
puts "\n✓ Test 9: No workflow match returns nil"
workflow = router.route_from_comment("Just a random comment", mock_task)
raise "FAIL: Expected nil for unmatched comment" unless workflow.nil?
puts "  PASS: Unmatched comment returns nil"

# Test 10: CommentTracker cleanup old state
puts "\n✓ Test 10: CommentTracker cleanup old state method exists"
raise "FAIL: cleanup_old_state method not found" unless tracker.respond_to?(:cleanup_old_state)
puts "  PASS: cleanup_old_state method exists"

puts "\n" + "=" * 60
puts "All integration tests passed! ✅"
puts "=" * 60
puts "\nReady for manual testing:"
puts "1. Create a task in 1 - Agent Tasks project"
puts "2. Let agent process it"
puts "3. Add a comment with instruction (e.g., 'research acme.com')"
puts "4. Wait 5 minutes for next cron run"
puts "5. Check if agent responded to comment"
puts "6. Verify comment is marked as processed in #{AgentConfig::COMMENT_STATE_FILE}"
