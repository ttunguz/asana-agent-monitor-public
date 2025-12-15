# spec/integration_test.rb
# Integration test to verify all components load correctly

puts "Running integration test..."
puts "-" * 50

# Test 1: Load configuration
puts "\n1. Loading configuration..."
begin
  require_relative '../config/agent_config'
  puts "   ✅ Configuration loaded"
  puts "   Project GID: #{AgentConfig::ASANA_PROJECT_GID}"
rescue => e
  puts "   ❌ Failed to load configuration: #{e.message}"
  exit 1
end

# Test 2: Load base workflow
puts "\n2. Loading base workflow..."
begin
  require_relative '../lib/workflows/base'
  puts "   ✅ Base workflow loaded"
rescue => e
  puts "   ❌ Failed to load base workflow: #{e.message}"
  exit 1
end

# Test 3: Load all workflow classes
puts "\n3. Loading workflow classes..."
workflows = ['open_url', 'company_research', 'article_summary', 'email_draft', 'newsletter_summary']
workflows.each do |workflow|
  begin
    require_relative "../lib/workflows/#{workflow}"
    puts "   ✅ #{workflow}.rb loaded"
  rescue => e
    puts "   ❌ Failed to load #{workflow}.rb: #{e.message}"
    exit 1
  end
end

# Test 4: Load workflow router
puts "\n4. Loading workflow router..."
begin
  require_relative '../lib/workflow_router'
  # Create a simple mock for AgentMonitor
  mock_monitor = Object.new
  router = WorkflowRouter.new(mock_monitor)
  puts "   ✅ WorkflowRouter loaded and initialized"
rescue => e
  puts "   ❌ Failed to load WorkflowRouter: #{e.message}"
  exit 1
end

# Test 5: Load agent monitor (without running)
puts "\n5. Loading agent monitor..."
begin
  require_relative '../lib/agent_monitor'
  puts "   ✅ AgentMonitor loaded"
  puts "   Note: Not initializing (requires ASANA_API_KEY)"
rescue => e
  puts "   ❌ Failed to load AgentMonitor: #{e.message}"
  exit 1
end

# Test 6: Verify TaskAPI is available
puts "\n6. Checking TaskAPI availability..."
begin
  require '/Users/tomasztunguz/.claude/code_mode/task_api'
  puts "   ✅ TaskAPI loaded"
rescue => e
  puts "   ⚠️  Warning: TaskAPI not available: #{e.message}"
  puts "   (This is OK if Code Mode APIs are not set up yet)"
end

puts "\n" + "-" * 50
puts "✅ Integration test complete!"
puts "\nAll core components loaded successfully."
puts "Ready for Phase 2: Workflow implementations"
