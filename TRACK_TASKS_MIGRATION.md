# TRACK Tasks Migration Summary

**Date:** December 14, 2025

## Problem Identified

All TRACK tasks and agent-related tasks were being created without a project assignment, making them harder to organize and track.

## Root Causes

1. **Workflow Base Class:** The `create_tom_task` helper method in `/Users/tomasztunguz/Documents/coding/asana-agent-monitor/lib/workflows/base.rb` was not specifying a project when creating tasks.

2. **AI-Generated Tasks:** The Gemini/Claude AI workflows can create tasks dynamically through prompts, and these weren't always being assigned to a project.

## Changes Made

### 1. Updated Workflow Base Class

**File:** `/Users/tomasztunguz/Documents/coding/asana-agent-monitor/lib/workflows/base.rb`

Added `project: 'agent_tasks'` parameter to the `create_tom_task` method:

```ruby
def create_tom_task(title:, notes:)
  require '/Users/tomasztunguz/.gemini/code_mode/task_api'

  TaskAPI.create(
    title: title,
    assignee: 'tom',
    due_date: Date.today.to_s,
    notes: notes,
    project: 'agent_tasks',  # NEW: Automatically assign to Agent Tasks project
    format: :concise
  )
rescue => e
  log_error("Failed to create task for Tom: #{e.message}")
  nil
end
```

This ensures all future tasks created by these workflows will be automatically added to the "Agent Tasks" project (GID: 1211959613518208).

### 2. Migrated Existing Tasks

**Migrated:** 91 tasks
**Success Rate:** 100%
**Failed:** 0

All existing TRACK tasks and agent-related tasks were successfully migrated to the Agent Tasks project using the migration script at `/tmp/migrate_to_agent_project.rb`.

### Task Categories Migrated

The following task patterns were migrated:
- Tasks with `[TRACK]` prefix (VCBench analysis tasks)
- Tasks with `VCBench Analysis :` or `VCBench Daily Summary`
- Tasks with `Summary :` (article/newsletter summaries)
- Tasks with `Research :` (company research tasks)
- Tasks with `agent` keyword
- Tasks with `research results` or `search results`
- Tasks with `newsletter digest`

## Sources of TRACK Tasks

1. **Company Research Workflow** (`lib/workflows/company_research.rb`)
   - Creates tasks like "Review [company] research"
   - Uses `create_tom_task` helper (now fixed)

2. **General Search Workflow** (`lib/workflows/general_search.rb`)
   - Creates tasks like "Search Results: [query]"
   - Uses `create_tom_task` helper (now fixed)

3. **Article Summary Workflow** (`lib/workflows/article_summary.rb`)
   - Creates tasks like "Read: [title]"
   - Uses `create_tom_task` helper (now fixed)

4. **Newsletter Summary Workflow** (`lib/workflows/newsletter_summary.rb`)
   - Creates tasks like "Newsletter digest - [dates]"
   - Uses `create_tom_task` helper (now fixed)

5. **Gemini/Claude AI Workflows** (`lib/workflows/gemini_code.rb`)
   - Can create tasks dynamically through AI prompts
   - These tasks should now include proper project assignment in their prompts

## Future Considerations

1. **AI Workflow Task Creation:** When the Gemini/Claude AI workflows create tasks through prompts, ensure the prompts include project assignment instructions.

2. **VCBench Daily Summary Tasks:** These are automatically created and should verify they're using the correct project.

3. **Monitoring:** Periodically check that new agent-created tasks are being properly assigned to the Agent Tasks project.

## Verification

To verify all TRACK tasks are now in the Agent Tasks project:

```bash
ruby -e "
require_relative '/Users/tomasztunguz/.claude/code_mode/task_api'
result = TaskAPI.search(query: 'TRACK', limit: 100, format: :detailed)
if result[:success]
  no_project = result[:data].select { |t| !t['project_name'] || t['project_name'].empty? }
  puts \"Tasks without project: #{no_project.length}\"
  puts \"Tasks with Agent Tasks project: #{result[:data].length - no_project.length}\"
end
"
```

## Files Modified

- `/Users/tomasztunguz/Documents/coding/asana-agent-monitor/lib/workflows/base.rb`

## Files Created

- `/tmp/migrate_to_agent_project.rb` (migration script, can be deleted after verification)
- `/Users/tomasztunguz/Documents/coding/asana-agent-monitor/TRACK_TASKS_MIGRATION.md` (this document)
