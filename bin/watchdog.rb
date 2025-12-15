#!/usr/bin/env ruby

require 'json'
require 'open3'
require 'tempfile'
require_relative 'health_check'

# Watchdog for Asana Agent Monitor
# Autonomous monitoring and recovery

class Watchdog
  SERVICE_LABEL = "com.theory.asana-monitor"

  def self.run
    puts "[#{Time.now}] Running watchdog..."
    health = HealthCheck.run
    
    # logic:
    # 1. Dead process -> Restart
    # 2. Stale logs (> 10 mins) -> Restart
    # 3. Recent errors -> Ask LLM
    
    if !health[:process][:running]
      log "Process monitor.rb NOT running. Restarting..."
      restart_service
      return
    end

    if health[:logs][:seconds_since_update] > 600
      log "Logs stale (#{health[:logs][:seconds_since_update]}s > 600s). Restarting..."
      restart_service
      return
    end

    if health[:logs][:recent_error_count] > 0
      log "Detected #{health[:logs][:recent_error_count]} recent errors. Consulting LLM..."
      decision = consult_llm(health)
      execute_decision(decision)
    else
      log "System healthy. Last log update: #{health[:logs][:seconds_since_update]}s ago."
    end
  end

  def self.consult_llm(health_data)
    prompt = <<~PROMPT
      You are a Site Reliability Engineer. Analyze the status of the Asana Agent Monitor.
      
      Context: The monitor is a Ruby daemon that polls Asana for tasks. 
      It logs to 'logs/agent.log'. It should update logs every 3 minutes.
      
      Status Data:
      #{JSON.pretty_generate(health_data)}
      
      Task:
      1. Analyze the 'recent_errors' to see if they are fatal (e.g., repeated crashes, auth failures) or transient (e.g. single timeout).
      2. Decide on an action:
         - NOTHING: If errors are transient or minor.
         - RESTART: If the process seems stuck, looping in errors, or needs a reset.
         - ALERT: If the issue is critical and requires human intervention (e.g. invalid API key).
      
      Output STRICT JSON only:
      {
        "status": "HEALTHY" | "DEGRADED" | "DOWN",
        "action": "NOTHING" | "RESTART" | "ALERT",
        "reason": "Brief explanation"
      }
    PROMPT

    # Call Gemini CLI
    output = call_gemini(prompt)
    
    begin
      # Clean up markdown code blocks if present
      json_str = output.gsub(/```json\n?|```/, '').strip
      JSON.parse(json_str)
    rescue JSON::ParserError => e
      log "Failed to parse LLM output: #{output}"
      { "action" => "NOTHING", "reason" => "LLM JSON parse error" }
    end
  end

  def self.call_gemini(prompt)
    prompt_file = Tempfile.new(['watchdog_prompt', '.txt'])
    prompt_file.write(prompt)
    prompt_file.close

    # Use gemini-1.5-flash for speed/cost, or gemini-2.0-flash-exp if available
    cmd = "cat #{prompt_file.path} | gemini --model gemini-1.5-flash --approval-mode yolo"
    
    stdout, stderr, status = Open3.capture3(cmd)
    prompt_file.unlink

    if status.success?
      stdout
    else
      log "Gemini CLI error: #{stderr}"
      "{}"
    end
  end

  def self.restart_service
    uid = Process.uid
    cmd = "launchctl kickstart -k gui/#{uid}/#{SERVICE_LABEL}"
    log "Executing: #{cmd}"
    system(cmd)
    
    # Notify
    send_alert("Asana Monitor Restarted", "Watchdog detected failure and restarted service.")
  end

  def self.execute_decision(decision)
    log "Decision: #{decision['action']} (#{decision['reason']})"
    
    case decision['action']
    when 'RESTART'
      restart_service
    when 'ALERT'
      send_alert("Asana Monitor Alert", decision['reason'])
    when 'NOTHING'
      # no-op
    end
  end

  def self.send_alert(title, message)
    # Mac Notification
    system("osascript -e 'display notification \"#{message}\" with title \"#{title}\"'")
  end

  def self.log(msg)
    puts "[#{Time.now}] #{msg}"
  end
end

if __FILE__ == $0
  Watchdog.run
end
