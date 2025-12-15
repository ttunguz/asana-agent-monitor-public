# spec/workflow_router_spec.rb

require_relative '../lib/workflow_router'
require_relative '../lib/workflows/gemini_code'

# Mock AgentMonitor class
class MockAgentMonitor
  def fetch_task_comments(task_gid)
    []
  end
end

# Mock task class
class MockTask
  attr_reader :name, :notes, :gid

  def initialize(name, notes = "", gid = "test")
    @name = name
    @notes = notes
    @gid = gid
  end
end

RSpec.describe WorkflowRouter do
  let(:agent_monitor) { MockAgentMonitor.new }
  let(:router) { WorkflowRouter.new(agent_monitor) }
  let(:task) { MockTask.new("Test task") }

  describe '#route' do
    it 'routes to the GeminiCode workflow' do
      workflow = router.route(task)
      expect(workflow).to be_a(Workflows::GeminiCode)
    end
  end

  describe '#route_from_comment' do
    it 'routes to the GeminiCode workflow' do
      workflow = router.route_from_comment("Test comment", task)
      expect(workflow).to be_a(Workflows::GeminiCode)
    end
  end
end