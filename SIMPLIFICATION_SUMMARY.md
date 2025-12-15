# Architecture Simplification Summary

## Overview

Removed keyword-based workflow routing in favor of direct Claude Code integration.

## Changes Made

### 1. New ClaudeCode Workflow (`lib/workflows/claude_code.rb`)

**What it does:**
- Takes task content (title + notes) or comment text
- Sends to Claude Code via stdin using `claude --print --dangerously-skip-permissions`
- Returns Claude's response as a task comment

**Key features:**
- Uses `--print` for non-interactive output
- Uses `--dangerously-skip-permissions` to auto-approve tool calls
- Pipes prompt via stdin to avoid shell escaping issues
- Handles both task-triggered and comment-triggered execution

### 2. Simplified Router (`lib/workflow_router.rb`)

**Before:** 150+ lines with keyword matching, URL detection, multiple workflow routing
**After:** 15 lines - always returns ClaudeCode workflow

```ruby
def route(task)
  Workflows::ClaudeCode.new(task)
end

def route_from_comment(comment_text, task)
  Workflows::ClaudeCode.new(task, triggered_by: :comment, comment_text: comment_text)
end
```

### 3. Cleaned Config (`config/agent_config.rb`)

**Removed:**
- `WORKFLOW_KEYWORDS` hash (general_search, company_research, etc.)
- `ARTICLE_PATH_PATTERNS` array

**Kept:**
- Asana project/workspace/team GIDs
- Check interval (5 minutes)
- Logging configuration
- Comment monitoring settings
- Assignee GIDs

### 4. Updated Monitor (`lib/agent_monitor.rb`)

**Removed:**
- "No workflow matched" warning messages
- Nil workflow checks (router always returns a workflow now)

**Kept:**
- Task processing logic
- Comment monitoring logic
- Error handling & logging

## Files Removed from Active Use

The following workflow files are no longer used (can be archived/deleted):
- `lib/workflows/open_url.rb`
- `lib/workflows/general_search.rb`
- `lib/workflows/company_research.rb`
- `lib/workflows/article_summary.rb`
- `lib/workflows/email_draft.rb`
- `lib/workflows/newsletter_summary.rb`

## Testing

Test script: `test_claude_workflow.rb`

```bash
ruby test_claude_workflow.rb
```

**Expected output:**
```
Testing ClaudeCode workflow...
Task: What is the capital of France?
Notes: Please answer briefly.

Result:
Success: true
Response:
🤖 Claude Code Response:

The capital of France is Paris.
```

## Benefits

1. **Simpler architecture** - 1 workflow instead of 6+
2. **No keyword maintenance** - No need to update keyword lists
3. **More flexible** - Claude can handle any request type
4. **Better autonomy** - Auto-approves tool calls for unattended operation
5. **Natural language** - Users can write tasks in plain English

## Migration Path

**For existing users:**
- Old task formats still work (e.g., "Research acme.com")
- New task formats also work (e.g., "Can you research acme.com and add them to Attio?")
- No changes required to existing tasks

**For new users:**
- Just write what you want in natural language
- No need to learn keywords or patterns

## Deployment

1. Code is ready to deploy
2. All syntax checks pass
3. Test passes successfully
4. No changes to cron job required (still runs every 5 minutes)
5. No changes to Asana project required

## Future Enhancements

Potential improvements:
- Add timeout handling for long-running Claude requests
- Add retry logic for Claude API failures
- Track Claude Code usage/costs
- Add rate limiting if needed
- Consider session management for multi-turn conversations

---

# Cron → launchd Migration (2025-11-20)

## Overview

Migrated **all 18 cron jobs** (including Asana monitor) from crontab to macOS launchd for more reliable scheduling.

## Why launchd?

macOS cron is unreliable:
- Stops after sleep/wake cycles
- No proper logging
- Poor error handling
- No automatic restart on failures

## What Changed

**Before**: 18 cron jobs in crontab (some not running for 24+ hours)
**After**: 18 launchd jobs in `~/Library/LaunchAgents/com.theory.*.plist`

## Benefits

- ✅ Survives sleep/wake cycles
- ✅ Better logging (separate stdout/stderr per job)
- ✅ Automatic restart on failures
- ✅ Native macOS integration
- ✅ No missed runs

## Jobs Migrated

All 18 cron jobs moved to launchd:
- **Asana agent monitor** - Every 5 min
- **Mail operations** - Mail check (5min), msmtp queue (2min), auto-archive (5min), dedup (daily 3am)
- **Backups** - Obsidian git backup & sync (daily 8:45am & 8:46am)
- **Research** - Reeder feeds (daily 6am), podcasts (daily 9am), LanceDB (weekly Sun 3am)
- **Newsletters** - Batch processing (every 2hrs), digest emails (9am & 5pm)
- **CRM** - ConvertKit digest (daily 9am), Attio metrics (every 6hrs)
- **VCBench** - Full sync (weekly Sun 2am), incremental (daily 2am), agent (daily 8am)
- **Daily briefings** - Weekdays 5am

## Management

```bash
# List all Theory jobs
launchctl list | grep com.theory

# Reload after editing plist
launchctl unload ~/Library/LaunchAgents/com.theory.asana-monitor.plist
launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist

# Check status
launchctl list | grep com.theory.asana-monitor

# View logs
tail -f logs/agent.log
```

## Backup

Original crontab: `~/Documents/coding/backups/crontab-backup-20251120.txt`

## Verification

```bash
$ launchctl list | grep com.theory | wc -l
18  # All loaded successfully
```

## Rollback

```bash
# Restore crontab if needed
crontab ~/Documents/coding/backups/crontab-backup-20251120.txt

# Unload launchd jobs
for plist in ~/Library/LaunchAgents/com.theory.*.plist; do
  launchctl unload "$plist"
done
```
