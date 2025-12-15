# spec/mocks/asana_client_mock.rb
require 'ostruct'

module AsanaClientMock
  def self.reset!
    @tasks = []
    @comments = []
    @completed_tasks = []
    @stories = {}
    @created_tasks = []
    @updated_titles = []
  end

  def self.setup_tasks(tasks)
    @tasks = tasks.map do |t|
      # Ensure task has all required fields
      t[:completed] = false unless t.key?(:completed)
      t[:notes] ||= ""
      t 
    end
  end

  def self.fetch_tasks(project_gid, completed_since: 'now')
    @tasks.map { |t| 
      {
        gid: t[:gid],
        name: t[:name],
        notes: t[:notes],
        completed: t[:completed]
      }
    }
  end

  def self.fetch_task_stories(task_id)
    @stories[task_id] || []
  end

  def self.add_comment(task_id:, comment:)
    @comments << { task_id: task_id, text: comment }
    
    # Store in stories for future fetch_task_stories calls
    @stories[task_id] ||= []
    @stories[task_id] << {
      gid: "comment_#{Time.now.to_i}_#{rand(1000)}",
      text: comment,
      created_at: Time.now.iso8601,
      created_by: { name: 'AI Agent' },
      type: 'comment'
    }
    
    { success: true }
  end

  def self.complete_task(task_id:)
    @completed_tasks << task_id
    { success: true }
  end
  
  def self.create_task(title:, notes: '', assignee: nil, due_on: nil, project_gid: nil)
    new_gid = "new_task_#{Time.now.to_i}_#{rand(1000)}"
    @created_tasks << {
      gid: new_gid,
      title: title,
      notes: notes,
      assignee: assignee,
      project_gid: project_gid
    }
    { success: true, gid: new_gid }
  end
  
  def self.update_task_title(task_id, new_title)
    @updated_titles << { task_id: task_id, new_title: new_title }
    { success: true }
  end

  # Inspection methods for assertions
  def self.get_comments(task_id)
    @comments.select { |c| c[:task_id] == task_id }
  end

  def self.task_completed?(task_id)
    @completed_tasks.include?(task_id)
  end
  
  def self.get_created_tasks
    @created_tasks
  end
  
  def self.get_updated_titles
    @updated_titles
  end
end
