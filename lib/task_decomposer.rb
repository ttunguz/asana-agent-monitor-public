# lib/task_decomposer.rb
# encoding: utf-8
# GEPA (Guided Exploration & Plan Adjustment) - Task decomposition system

class TaskDecomposer
  Step = Struct.new(:number, :name, :description, :success_criteria, :retry_on_failure, keyword_init: true)

  def self.decompose(task, comment_text = nil)
    # Combine task name, notes, & comment for analysis
    text = [task.name, task.notes, comment_text].compact.join(" ")

    # Detect decomposition patterns
    if multi_target_research?(text)
      decompose_multi_target_research(text)
    elsif multi_step_workflow?(text)
      decompose_multi_step_workflow(text)
    else
      # Single step - no decomposition needed
      [Step.new(
        number: 1,
        name: "Execute task",
        description: text,
        success_criteria: "Task completed successfully",
        retry_on_failure: false
      )]
    end
  end

  def self.should_decompose?(task, comment_text = nil)
    # Returns true if task should use GEPA decomposition
    steps = decompose(task, comment_text)
    steps.size > 1
  end

  private

  def self.multi_target_research?(text)
    # Detect patterns like "research X, Y, and Z" or "research X.com, Y.com"
    downcase_text = text.downcase

    return false unless downcase_text.include?("research") || downcase_text.include?("analyze")

    # Count domains (.com, .io, .ai, .so, etc.)
    # IMPORTANT : Exclude domains that are part of email addresses (preceded by @)
    domain_count = text.scan(/(?<!@)\b[\w-]+\.(?:com|io|ai|co|net|org|so)\b/).size

    # Also check for "and" or commas suggesting multiple items
    has_multiple_items = text.include?(" and ") || text.scan(/,/).size >= 2

    domain_count >= 2 || (domain_count >= 1 && has_multiple_items)
  end

  def self.multi_step_workflow?(text)
    # Detect multi-step keywords: "then", "after", "if...then", "first...then"
    downcase_text = text.downcase

    downcase_text.include?("then ") ||
      downcase_text.include?("after ") ||
      downcase_text.include?("first ") ||
      (downcase_text.include?("if ") && downcase_text.include?("add")) ||
      downcase_text.match?(/\d+\.\s+/) # Numbered list (1. 2. 3.)
  end

  def self.decompose_multi_target_research(text)
    # Extract domains using regex (support .com, .io, .ai, .so, etc.)
    # IMPORTANT : Exclude domains that are part of email addresses (preceded by @)
    domains = text.scan(/(?<!@)\b([\w-]+\.(?:com|io|ai|co|net|org|so))\b/).flatten.uniq

    return single_step(text) if domains.empty?

    domains.map.with_index do |domain, i|
      Step.new(
        number: i + 1,
        name: "Research #{domain}",
        description: build_research_description(text, domain),
        success_criteria: "Research completed & insights provided",
        retry_on_failure: true # Retry research if API fails
      )
    end
  end

  def self.decompose_multi_step_workflow(text)
    # For now, return single step
    # In future, could parse "first X, then Y" into explicit steps
    # This is a placeholder for more sophisticated decomposition
    single_step(text)
  end

  def self.build_research_description(original_text, domain)
    # Build step description based on original task requirements
    desc = "Research #{domain}"
    
    # Preserve specific instructions from original text if simple
    # but avoid copying specific internal jargon
    
    desc
  end

  def self.single_step(text)
    [Step.new(
      number: 1,
      name: "Execute task",
      description: text,
      success_criteria: "Task completed successfully",
      retry_on_failure: false
    )]
  end
end