# Asana Agent Monitor - Title Update Feature

## Overview
Added automatic task title updates to make task titles more descriptive after processing.

## Changes Made

### Modified Files
- `lib/agent_monitor.rb`

### New Methods

#### `update_task_title(task, result)`
- Called after successful workflow execution
- Generates & updates task title based on content
- Uses TaskAPI.update() for safe title updates
- Logs title changes for debugging
- Gracefully handles update failures

#### `generate_descriptive_title(task, result)`
- Generates descriptive titles from task content
- Priority order:
  1. First meaningful line from task notes (if >10 chars)
  2. First non-emoji line from workflow result (if >10 chars)
  3. Fallback: `{current_title} - Processed`
- Skips update if current title is already descriptive (>30 chars)
- Limits title length to 120 chars (Asana supports ~1024 but keeps reasonable)

#### `clean_title(title)`
- Removes markdown formatting (bold, italic, code blocks, headers)
- Strips URLs (https://...)
- Removes emoji (🤖✅❌⚠️🔄📧)
- Collapses multiple spaces
- Returns clean, readable title

### Integration Points

#### `process_task(task)`
- Calls `update_task_title()` after successful workflow execution
- Updates title for tasks processed from incomplete queue

#### `process_comment(task, comment)`
- Calls `update_task_title()` after successful comment-triggered workflow
- Updates title for tasks triggered by user comments

## Behavior

### When Title Updates
- Task has short title (<= 30 chars)
- Workflow execution succeeds
- New title is different from current title
- New title is meaningful (>5 chars)

### When Title Skips Update
- Task already has long descriptive title (>30 chars)
- New title is same as current title
- Workflow execution fails
- New title is too short (<= 5 chars)
- TaskAPI update fails (logs warning, doesn't crash)

## Examples

### Example 1: Task with Short Title & Detailed Notes
```
Before: "Task"
Notes:  "Research Acme Corp\nFind key metrics and funding info"
After:  "Research Acme Corp"
```

### Example 2: Task with Empty Notes, Uses Result Summary
```
Before: "Query"
Notes:  ""
Result: "Searched for startup funding rounds and found 3 companies meeting criteria"
After:  "Searched for startup funding rounds and found 3 companies meeting criteria"
```

### Example 3: Task with Long Title (Skipped)
```
Before: "Research Acme Corp and evaluate investment opportunity"
After:  (No change - title already descriptive)
```

### Example 4: Task with Markdown/URLs in Notes
```
Before: "Check"
Notes:  "**Bold text** with https://example.com URL"
After:  "Bold text with URL"
```

## Testing

### Manual Testing
1. Create test task with short title (e.g., "Task")
2. Add detailed notes or URL
3. Trigger agent processing
4. Verify title updates to first line of notes (cleaned)

### Expected Logs
```
[2025-12-07 10:30:45] [INFO] Processing task 123456: Task
[2025-12-07 10:30:46] [INFO]   Routing to Workflows::GeminiCode
[2025-12-07 10:30:50] [INFO]   ✅ Workflow succeeded
[2025-12-07 10:30:50] [INFO]   Updating task title: 'Task' → 'Research Acme Corp'
```

## Dependencies
- Requires TaskAPI.update() method (already exists in task_api.rb)
- Uses existing logging infrastructure
- No new external dependencies

## Error Handling
- Title update failures are logged as warnings (⚠️)
- Failures don't prevent task completion or comment posting
- Agent continues processing even if title update fails

## Future Enhancements
- Add AI-powered title generation using LLM
- Support custom title templates per project
- Allow user preferences for title update behavior
- Add title length preferences to config

## Configuration
No new configuration required. Feature is automatically enabled for all tasks.

To disable (if needed):
```ruby
# In lib/agent_monitor.rb, comment out in process_task():
# update_task_title(task, result)
```

## Rollback
To revert changes:
```bash
git checkout HEAD~1 lib/agent_monitor.rb
```
