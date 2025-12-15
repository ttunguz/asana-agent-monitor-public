#!/usr/bin/env ruby

require 'json'
require 'time'
require 'open3'

# Health Check Probe for Asana Agent Monitor
# Gathers system state for LLM analysis

class HealthCheck
  SERVICE_LABEL = "com.theory.asana-monitor"
  LOG_FILE = File.expand_path("../logs/agent.log", __dir__)
  PROCESS_NAME = "monitor.rb"
  
  def self.run
    new.report
  end

  def report
    {
      timestamp: Time.now.iso8601,
      process: check_process,
      launchd: check_launchd,
      logs: check_logs,
      system: check_system
    }
  end

  private

  def check_process
    # Grep for monitor.rb, exclude grep itself
    pid = `pgrep -f "#{PROCESS_NAME}"`.strip
    {
      running: !pid.empty?,
      pid: pid.to_i
    }
  end

  def check_launchd
    # - code: exit code or status
    # - status: 0 usually means running
    output, status = Open3.capture2("launchctl list #{SERVICE_LABEL}")
    
    if status.success?
      # Parse the output which is in "PID Status Label" format or similar? 
      # Actually launchctl list <label> returns plist-like format or key-value pairs depending on OS version
      # simpler: launchctl list returns "PID\tStatus\tLabel" for all services, 
      # but "launchctl list label" usually outputs details.
      
      # Let's parse the key properties
      {
        exists: true,
        details: output.split("\n").map(&:strip).join(", ")
      }
    else
      {
        exists: false,
        error: "Service not found in launchctl"
      }
    end
  end

  def check_logs
    return { exists: false } unless File.exist?(LOG_FILE)

    stat = File.stat(LOG_FILE)
    last_modified = stat.mtime
    seconds_since_update = Time.now - last_modified
    
    # Read last 50 lines for errors
    last_lines = `tail -n 50 "#{LOG_FILE}"`.split("\n")
    errors = last_lines.select { |l| l.match?(/ERROR|Exception|Traceback/i) }

    {
      exists: true,
      last_modified: last_modified.iso8601,
      seconds_since_update: seconds_since_update.to_i,
      recent_error_count: errors.size,
      recent_errors: errors.last(5) # Just the last 5 for context
    }
  end
  
  def check_system
    {
      uptime: `uptime`.strip,
      disk_space: `df -h .`.split("\n")[1]
    }
  end
end

if __FILE__ == $0
  puts JSON.pretty_generate(HealthCheck.run)
end
