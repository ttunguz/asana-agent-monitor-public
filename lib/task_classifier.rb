# lib/task_classifier.rb
# encoding: utf-8
# Classifies tasks into categories for appropriate prompt template selection

class TaskClassifier
  EMAIL_KEYWORDS = %w[email draft send reply message mail compose]
  COMPANY_KEYWORDS = %w[research company attio vcbench harmonic competitor startup domain market\ map theorymcp]
  SIMPLE_QUERY_KEYWORDS = %w[weather time what when where who how why]

  def self.classify(task, comment_text = nil)
    # Combine task name, notes, & comment text for analysis
    text = [task.name, task.notes, comment_text].compact.join(" ").downcase

    return :simple_query if simple_query?(text)
    return :email if email_task?(text)
    return :company_research if company_research?(text)
    :general
  end

  private

  def self.simple_query?(text)
    # Single sentence, no Code Mode API keywords, has question word
    return false if text.length > 100
    return false if text.include?("attio") || text.include?("email") || text.include?("send") || text.include?("draft")

    # Must have a question word to be a simple query
    SIMPLE_QUERY_KEYWORDS.any? { |keyword| text.include?(keyword) }
  end

  def self.email_task?(text)
    EMAIL_KEYWORDS.any? { |keyword| text.include?(keyword) }
  end

  def self.company_research?(text)
    COMPANY_KEYWORDS.any? { |keyword| text.include?(keyword) }
  end
end
