# spec/monitor_test.rb
# Test that monitor script can be loaded and executed

puts "Testing monitor script..."
puts "-" * 50

# Test 1: Script exists
puts "\n1. Checking if monitor script exists..."
monitor_path = File.expand_path('../bin/monitor.rb', __dir__)
if File.exist?(monitor_path)
  puts "   ✅ Monitor script exists: #{monitor_path}"
else
  puts "   ❌ Monitor script not found"
  exit 1
end

# Test 2: Script is executable
puts "\n2. Checking if monitor script is executable..."
if File.executable?(monitor_path)
  puts "   ✅ Monitor script is executable"
else
  puts "   ❌ Monitor script is not executable"
  exit 1
end

# Test 3: Load test (without running)
puts "\n3. Testing script load..."
begin
  # Load the lib path
  $LOAD_PATH.unshift File.expand_path('../lib', __dir__)
  require 'agent_monitor'
  puts "   ✅ AgentMonitor class loaded successfully"
rescue => e
  puts "   ❌ Failed to load: #{e.message}"
  exit 1
end

# Test 4: Check required env var message
puts "\n4. Checking ASANA_API_KEY requirement..."
if ENV['ASANA_API_KEY'].nil? || ENV['ASANA_API_KEY'].empty?
  puts "   ⚠️  ASANA_API_KEY not set (expected for testing)"
  puts "   Note: Set ASANA_API_KEY in environment to run monitor"
else
  puts "   ✅ ASANA_API_KEY is set"
end

puts "\n" + "-" * 50
puts "✅ Monitor script verification complete!"
puts "\nTo run manually (requires ASANA_API_KEY):"
puts "  cd ~/Documents/coding/asana-agent-monitor"
puts "  ./bin/monitor.rb"
puts "\nTo run with logging:"
puts "  ./bin/monitor.rb >> logs/agent.log 2>&1"
