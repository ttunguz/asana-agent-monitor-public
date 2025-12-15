# lib/conversation_summarizer.rb
# encoding: utf-8
# Summarizes old comments when conversation history exceeds token budget

class ConversationSummarizer
  MAX_FULL_HISTORY_CHARS = 5000

  def self.summarize_if_needed(comments)
    return comments if comments.nil? || comments.empty?

    # Calculate total character count
    total_chars = comments.sum { |c| (c[:text] || "").length }

    return comments if total_chars < MAX_FULL_HISTORY_CHARS

    # Keep last 3 comments in full, summarize the rest
    recent = comments.last(3)
    old = comments[0...-3]

    return comments if old.empty? # Nothing to summarize

    summary_comment = {
      gid: "summary",
      text: summarize_comments(old),
      created_by: "System",
      created_at: old.first[:created_at]
    }

    [summary_comment] + recent
  end

  private

  def self.summarize_comments(comments)
    return "" if comments.empty?

    count = comments.size
    topics = extract_topics(comments)

    "Previous conversation (#{count} comments) : #{topics.join(', ')}"
  end

  def self.extract_topics(comments)
    # Simple topic extraction - look for key phrases
    topics = []

    all_text = comments.map { |c| c[:text] }.join(" ").downcase

    topics << "company research" if all_text.include?("research") || all_text.include?("company")
    topics << "email discussion" if all_text.include?("email") || all_text.include?("draft")
    topics << "task management" if all_text.include?("task") || all_text.include?("asana")
    topics << "data analysis" if all_text.include?("data") || all_text.include?("analyze")
    topics << "general questions" if topics.empty?

    topics
  end
end
