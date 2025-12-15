#!/usr/bin/env ruby

# bin/monitor.rb - Long-running daemon with KeepAlive

$stdout.sync = true

# Add lib to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'agent_monitor'
require_relative '../config/agent_config'

# Signal handling for clean shutdown
@running = true

Signal.trap('TERM') do
  puts "[#{Time.now}] Received SIGTERM, shutting down gracefully..."
  @running = false
end

Signal.trap('INT') do
  puts "[#{Time.now}] Received SIGINT, shutting down gracefully..."
  @running = false
end

# Log startup
interval = AgentConfig::CHECK_INTERVAL_MINUTES * 60
puts "[#{Time.now}] Asana Agent Monitor daemon starting..."
puts "[#{Time.now}] Polling every #{interval} seconds (#{AgentConfig::CHECK_INTERVAL_MINUTES} minutes)"
puts "[#{Time.now}] Press Ctrl+C to stop"

# Main daemon loop
while @running
  begin
    # Run one monitoring cycle
    AgentMonitor.run

    # Wait for interval (unless shutting down)
    interval.times do
      break unless @running
      sleep 1
    end
  rescue => e
    begin
      # Log error but don't crash - keep daemon running
      puts "[#{Time.now}] ERROR in monitor cycle: #{e.class}: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    rescue Errno::EPIPE
      # If stdout is broken, we can't log. Just wait and retry.
    end

    # Wait 30 seconds before retry after error
    30.times do
      break unless @running
      sleep 1
    end
  end
end


puts "[#{Time.now}] Asana Agent Monitor daemon stopped."