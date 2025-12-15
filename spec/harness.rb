# spec/harness.rb
require 'minitest/autorun'
require 'minitest/spec'

# Set environment to testing
ENV['ASANA_API_KEY'] = 'test_key'
ENV['GEMINI_API_KEY'] = 'test_key'

# Load mocks FIRST so they override real implementations (or are loaded in place of them)
require_relative 'mocks/asana_client_mock'
require_relative 'mocks/llm_client_mock'

# We need to suppress the real AsanaClient require in the app code
# or patch it. Since we can't easily patch 'require', we'll rely on
# Ruby's behavior where requiring the same file twice doesn't reload it
# if we're careful. But AsanaClient is a module.
#
# Strategy: Load app files, then patch the constants.
# However, agent_monitor.rb does `require_relative 'asana_client'`.
# We need to make sure our mock definition wins.

# Define AsanaClient as a module that delegates to AsanaClientMock
module AsanaClient
  def self.add_comment(*args, **kwargs); AsanaClientMock.add_comment(*args, **kwargs); end
  def self.complete_task(*args, **kwargs); AsanaClientMock.complete_task(*args, **kwargs); end
  def self.fetch_tasks(*args, **kwargs); AsanaClientMock.fetch_tasks(*args, **kwargs); end
  def self.fetch_task_stories(*args, **kwargs); AsanaClientMock.fetch_task_stories(*args, **kwargs); end
  def self.create_task(*args, **kwargs); AsanaClientMock.create_task(*args, **kwargs); end
  def self.update_task_title(*args, **kwargs); AsanaClientMock.update_task_title(*args, **kwargs); end
end

# Prevent loading the real AsanaClient file by tricking $LOADED_FEATURES
real_asana_client_path = File.expand_path('../lib/asana_client.rb', __dir__)
$LOADED_FEATURES << real_asana_client_path

# Prevent loading the real LLM::BaseClient file by tricking $LOADED_FEATURES
real_llm_client_path = File.expand_path('../lib/llm/base_client.rb', __dir__)
$LOADED_FEATURES << real_llm_client_path

# Now load the application
require_relative '../lib/agent_monitor'

describe 'Asana Agent Monitor Integration' do
  before do
    AsanaClientMock.reset!
    LLMClientMock.reset!
    
    # Silence logger
    AgentConfig.send(:remove_const, :LOG_FILE) if defined?(AgentConfig::LOG_FILE)
    AgentConfig.const_set(:LOG_FILE, '/dev/null')
    
    # Configure project GIDs for testing
    AgentConfig.send(:remove_const, :ASANA_PROJECT_GIDS) if defined?(AgentConfig::ASANA_PROJECT_GIDS)
    AgentConfig.const_set(:ASANA_PROJECT_GIDS, ['project_1'])
  end

  it 'processes a search task correctly' do
    # Setup
    task_gid = 'task_1'
    project_gid = 'project_1'
    AsanaClientMock.setup_tasks([
      { gid: task_gid, name: 'Search for best hiking boots', notes: '', project_gid: project_gid }
    ])
    
    # Mock LLM
    LLMClientMock.mock_response(/hiking boots/, "I found these boots: 1. Salomon Quest...")
    
    # Run
    monitor = AgentMonitor.new
    monitor.run
    
    # Verify
    comments = AsanaClientMock.get_comments(task_gid)
    refute_empty comments, "Should have added a comment"
    assert_match /Salomon Quest/, comments.first[:text]
    assert_match /✅/, comments.first[:text]
    
    # Verify follow-up task was created (since it's a search)
    created_tasks = AsanaClientMock.get_created_tasks
    refute_empty created_tasks
    assert_match /Hiking boots/i, created_tasks.first[:title]
  end

  it 'processes an article summary task' do
    # Setup
    task_gid = 'task_2'
    AsanaClientMock.setup_tasks([
      { gid: task_gid, name: 'Summarize https://example.com/article', notes: '' }
    ])
    
    # Mock curl (we need to stub Open3.capture3 for ArticleSummary)
    Workflows::ArticleSummary.class_eval do
      def fetch_and_summarize(url)
        {
          success: true,
          title: "Test Article",
          summary: "This is a summary of the test article."
        }
      end
    end
    
    # Run
    monitor = AgentMonitor.new
    monitor.run
    
    # Verify
    comments = AsanaClientMock.get_comments(task_gid)
    refute_empty comments
    assert_match /Test Article/, comments.first[:text]
    assert_match /summary of the test article/, comments.first[:text]
  end

  it 'processes an email draft task' do
    # Setup
    task_gid = 'task_3'
    AsanaClientMock.setup_tasks([
      { gid: task_gid, name: 'Email Draft to alice@example.com about project', notes: '' }
    ])
    
    # Run
    monitor = AgentMonitor.new
    monitor.run
    
    # Verify
    comments = AsanaClientMock.get_comments(task_gid)
    refute_empty comments
    assert_match /To : alice@example.com/, comments.first[:text]
    assert_match /Subject : project/, comments.first[:text]
  end

  it 'handles generic tasks with AI Agent' do
    # Setup
    task_gid = 'task_4'
    AsanaClientMock.setup_tasks([
      { gid: task_gid, name: 'Explain quantum computing', notes: '' }
    ])
    
    LLMClientMock.mock_response(/quantum computing/, "Quantum computing uses qubits...")
    
    # Run
    monitor = AgentMonitor.new
    monitor.run
    
    # Verify
    comments = AsanaClientMock.get_comments(task_gid)
    refute_empty comments
    assert_match /Quantum computing/, comments.first[:text]
    assert_match /🤖/, comments.first[:text]
  end

  it 'updates task title after successful processing' do
    # Setup
    task_gid = 'task_5'
    AsanaClientMock.setup_tasks([
      { gid: task_gid, name: 'research apple', notes: '' }
    ])
    
    LLMClientMock.mock_response(/apple/, "Apple is a tech company...")
    
    # Run
    monitor = AgentMonitor.new
    monitor.run
    
    # Verify title update
    updates = AsanaClientMock.get_updated_titles
    refute_empty updates
    assert_equal task_gid, updates.first[:task_id]
    # Fallback title behavior uses first line of result if not specific
    assert_match /Apple is a tech company/i, updates.first[:new_title]
  end
end
