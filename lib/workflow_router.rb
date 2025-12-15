# lib/workflow_router.rb
# Router for Asana Agent Monitor

require_relative 'workflows/ai_agent'
require_relative 'workflows/general_search'
require_relative 'workflows/email_draft'
require_relative 'workflows/article_summary'
require_relative 'workflows/newsletter_summary'

class WorkflowRouter
  def initialize(agent_monitor)
    @agent_monitor = agent_monitor
  end

  def route(task)
    # Basic routing based on task content
    text = (task.name + " " + task.notes).downcase
    
    if text.include?('newsletter') || text.include?('digest')
      Workflows::NewsletterSummary.new(task)
    elsif text.include?('email') || text.include?('draft')
      Workflows::EmailDraft.new(task)
    elsif text.match?(/https?:\/\//) && (text.include?('summarize') || text.include?('summary'))
      Workflows::ArticleSummary.new(task)
    elsif text.include?('search') || text.include?('find')
      Workflows::GeneralSearch.new(task)
    else
      # Default to AI Agent (Gemini/Claude)
      Workflows::AiAgent.new(task)
    end
  end

  def route_from_comment(comment_text, task)
    all_comments = @agent_monitor.fetch_task_comments(task.gid)
    
    # Simple routing based on comment content
    text = comment_text.downcase
    
    if text.include?('search')
      Workflows::GeneralSearch.new(task, triggered_by: :comment, comment_text: comment_text, all_comments: all_comments)
    elsif text.include?('email') || text.include?('draft')
      Workflows::EmailDraft.new(task, triggered_by: :comment, comment_text: comment_text, all_comments: all_comments)
    else
      # Default to AI Agent
      Workflows::AiAgent.new(task, triggered_by: :comment, comment_text: comment_text, all_comments: all_comments)
    end
  end
end