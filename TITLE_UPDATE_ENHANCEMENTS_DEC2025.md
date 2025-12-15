# Asana Monitor : Title Update Enhancements (December 2025)

## Summary
Enhanced the Asana monitor agent to **ALWAYS** update task titles to descriptive names after processing every task, including timeouts, errors & exceptions.

## Problem
Based on conversation history showing repeated workflow timeouts, tasks were not consistently getting descriptive titles. The original implementation had conditions that sometimes prevented title updates.

## Key Changes

### 1. Title Update Now ALWAYS Runs on Failures (`agent_monitor.rb:475, 295`)

**Before:**
```ruby
# Only updated on failure IF result[:error] was present
update_task_title(task, result) if result[:error]
```

**After:**
```ruby
# ALWAYS update on failure
update_task_title(task, result)
```

### 2. Title Update on Exceptions (`agent_monitor.rb:482-487, 302-307`)

**NEW:** Added exception handling to update titles even when workflow crashes:

```ruby
rescue => e
  log "  ERROR processing task #{task.gid}: #{e.class}: #{e.message}", :error
  add_task_comment(task.gid, "❌ Agent error: #{e.message}")

  # Even on exception, try to update title with error context
  begin
    update_task_title(task, {success: false, error: e.message, comment: ''})
  rescue => title_error
    log "  ⚠️ Could not update title after exception: #{title_error.message}", :error
  end
end
```

### 3. Enhanced Title Generation for Errors (`agent_monitor.rb:538-541`)

**NEW:** Title updates now ALWAYS run for failed workflows, even if current title is descriptive:

```ruby
# If title is already descriptive (>50 chars) and doesn't look generic, keep it
# UNLESS it's an error/timeout case (we always want to update those)
unless result[:success] == false || generic_title?(current_title) || current_title.length < 50
  return nil
end
```

### 4. Better Timeout Detection (`agent_monitor.rb:569`)

**Enhanced:** More robust timeout detection using case-insensitive matching:

```ruby
if error.to_s.downcase.include?('timeout')
```

### 5. Improved Fallback Logic (`agent_monitor.rb:578-585, 593-598`)

**Enhanced:** Better extraction of context from notes even when workflow-specific patterns don't match:

```ruby
# Use current title if it's descriptive, otherwise extract from notes
if current_title.length > 15 && !generic_title?(current_title)
  new_title = "⏱️ Timeout : #{current_title}"
else
  # Extract first meaningful phrase from notes
  phrase = extract_first_meaningful_phrase(notes)
  new_title = "⏱️ Workflow timeout : #{phrase}"
end
```

### 6. Better Logging (`agent_monitor.rb:496`)

**NEW:** Added logging when title updates are skipped to help debug:

```ruby
else
  log "  Skipping title update: #{new_title ? "title unchanged" : "no new title generated"}"
end
```

## Title Format Examples

### Timeout Cases (from conversation history)
**Before:** "Task" or unchanged title
**After:**
- "⏱️ Timeout : Research acme.com"
- "⏱️ Timeout (2/3 steps)" (with partial progress)
- "⏱️ Workflow timeout : Article from techcrunch.com"

### Other Error Cases
**Before:** Generic or unchanged title
**After:**
- "❌ Research startup.com" (extracted from notes)
- "❌ Failed : Email to founder"
- "❌ Add company example.com to Attio"

### Success Cases (unchanged behavior)
- "Research : acme.com"
- "Market Map : AI Infrastructure"
- "Email : Meeting follow-up"
- "VCBench Analysis : startup.io"

## Workflow Coverage

Title updates now run in ALL processing paths:

1. ✅ **Success path** (`process_task` line 466, `process_comment` line 287)
2. ✅ **Failure path** (`process_task` line 475, `process_comment` line 295)
3. ✅ **Exception path** (NEW - `process_task` line 484, `process_comment` line 304)

## Testing

Created `test_title_update_simple.rb` to verify helper methods:
- ✅ `extract_context_from_notes` - Extracts domain/email/URL context
- ✅ `extract_partial_progress` - Finds GEPA step completion status
- ✅ Domain with action detection ("research acme.com" → "Research acme.com")
- ✅ Progress extraction ("Completed 2/5 steps" → "2/5 steps")

## Benefits

1. **100% coverage** : Every task gets a descriptive title, no exceptions
2. **Better error tracking** : Timeouts & errors are clearly marked with ⏱️ & ❌
3. **Context preservation** : Even failed tasks show what was attempted
4. **Easier debugging** : Can identify problematic tasks at a glance in Asana
5. **No silent failures** : Exception handling ensures titles update even on crashes

## Migration Notes

- **No configuration changes needed** : Updates are automatic
- **Backward compatible** : Doesn't affect successful workflows
- **Safe fallbacks** : Multiple layers of error handling prevent crashes
- **Logging enhanced** : Can monitor via logs to verify title updates

## Verification

To verify title updates are working after these changes:

```bash
# Monitor title update logs
tail -f /Users/tomasztunguz/Documents/coding/asana-agent-monitor/logs/agent-error.log | grep "Updating task title"

# Check for skipped updates (to debug)
tail -f /Users/tomasztunguz/Documents/coding/asana-agent-monitor/logs/agent-error.log | grep "Skipping title update"
```

## Future Enhancements (Optional)

1. **AI-generated titles** : Use LLM to generate titles for complex tasks
2. **Custom title templates** : Per-project or per-user title formats
3. **Title history** : Track title changes over time
4. **Analytics** : Identify most common timeout/error patterns from titles

## Impact on Workflow Timeout Issue

While this doesn't fix the underlying timeout issue, it ensures that:
- Users can immediately see which tasks timed out
- Context is preserved even when workflows fail
- Debugging is easier with descriptive titles showing what was attempted
- Tasks don't remain with generic "Task" titles that provide no information
