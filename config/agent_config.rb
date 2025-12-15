require 'yaml'
require 'fileutils'

module AgentConfig
  # Locate config file
  CONFIG_FILE = ENV['AGENT_CONFIG'] || File.expand_path('../config.yml', __FILE__)
  
  # Load configuration
  if File.exist?(CONFIG_FILE)
    config_data = YAML.load_file(CONFIG_FILE)
  else
    # Fallback/Defaults if no config file (or warn user)
    puts "[WARN] Config file not found at #{CONFIG_FILE}. Using defaults/ENV."
    config_data = {
      'asana' => {}, 
      'monitoring' => {}, 
      'logging' => {}, 
      'ai' => {},
      'assignees' => {}
    }
  end

  # Asana Configuration
  ASANA_PROJECT_GIDS = config_data.dig('asana', 'project_gids') || []
  ASANA_WORKSPACE_GID = config_data.dig('asana', 'workspace_gid') || ENV['ASANA_WORKSPACE_GID']
  AGENT_NAME = config_data.dig('asana', 'agent_name') || 'AI Agent'

  # Assignees
  ASSIGNEES = config_data['assignees'] || {}

  # Monitoring
  CHECK_INTERVAL_MINUTES = config_data.dig('monitoring', 'check_interval_minutes') || 5
  ENABLE_COMMENT_MONITORING = config_data.dig('monitoring', 'enable_comment_monitoring') || true
  MAX_CONCURRENT_WORKERS = config_data.dig('monitoring', 'max_concurrent_workers') || 5
  TASK_TIMEOUT = config_data.dig('monitoring', 'task_timeout') || 300
  
  # AI Provider
  AI_PROVIDER = config_data.dig('ai', 'provider') || 'gemini'

  # Logging
  LOG_DIR = File.expand_path(config_data.dig('logging', 'log_dir') || './logs')
  FileUtils.mkdir_p(LOG_DIR)
  LOG_FILE = File.join(LOG_DIR, 'agent.log')
  COMMENT_STATE_FILE = File.join(LOG_DIR, 'processed_comments.json')
end