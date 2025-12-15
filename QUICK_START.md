# Quick Start Guide : Task Title Updates

## What Changed?
The Asana agent monitor now automatically updates task titles to be more descriptive after processing tasks. This makes it easier to identify what each task is about at a glance.

## Key Features

✅ **Automatic Updates** : Titles updated after successful workflow execution
✅ **Workflow-Aware** : Different title formats for research, emails, summaries, searches
✅ **Multi-User Support** : Works for tasks assigned to Tom, Art, or Lauren
✅ **Non-Intrusive** : Only updates short/generic titles (<40 chars)
✅ **Error-Tolerant** : Title update failures don't affect task processing

## Example Transformations

| Original Title | Task Content | New Title |
|----------------|--------------|-----------|
| "Test task" | Research acme.com | "Research: acme.com" |
| "Quick task" | Draft email with Subject: Follow-up | "Email: Follow-up" |
| "Read this" | https://techcrunch.com/article | "Summary: techcrunch.com" |
| "Look up info" | Search for AI companies | "Search: AI companies" |

## Testing

### 1. Test Title Generation Logic (Safe)
```bash
cd /Users/tomasztunguz/Documents/coding/asana-agent-monitor
ruby test_title_update.rb
```

### 2. Test Live API Update (Requires Test Task)
```bash
export TEST_TASK_GID="your_test_task_gid"
export ASANA_API_KEY="your_api_key"
ruby test_live_title_update.rb
```

### 3. Monitor in Production
```bash
# Watch for title updates in logs
tail -f logs/agent.log | grep "Updating task title"
```

## Troubleshooting

### Title Not Updated
Check if:
- [ ] Workflow succeeded (updates only on success)
- [ ] Original title is <40 characters (longer titles preserved)
- [ ] Generated title is different from original
- [ ] Generated title is >5 characters

### API Errors
- Verify `ASANA_API_KEY` is set correctly
- Check task exists & is accessible
- Review logs for detailed error messages

### Title Format Issues
- Check task notes contain recognizable patterns
- Review workflow result comment for extractable information
- See `TITLE_UPDATE_FEATURE.md` for pattern details

## Documentation

- **Feature Details** : `TITLE_UPDATE_FEATURE.md`
- **Update Summary** : `UPDATE_SUMMARY.md`
- **Test Scripts** :
  - `test_title_update.rb` (safe, mock data)
  - `test_live_title_update.rb` (live API test)

## Monitoring

### Check Logs for Updates
```bash
# Show recent title updates
grep "Updating task title" logs/agent.log | tail -20

# Show successful updates
grep "✅ Task title updated" logs/agent.log | tail -20

# Show failures
grep "⚠️ Failed to update task title" logs/agent.log
```

### Verify in Asana
1. Open processed task in Asana
2. Check if title was updated
3. Review task history for title change event

## Configuration

No configuration needed! The feature is enabled by default.

### Temporary Disable (if needed)
Comment out these lines in `lib/agent_monitor.rb`:
```ruby
# Line 463
# update_task_title(task, result)

# Line 287
# update_task_title(task, result)
```

## Questions?

Check the documentation:
1. `TITLE_UPDATE_FEATURE.md` - Complete feature guide
2. `UPDATE_SUMMARY.md` - Change summary & deployment notes
3. `logs/agent.log` - Runtime logs & error messages

Or review the code:
- `lib/agent_monitor.rb` (lines 477-604)
