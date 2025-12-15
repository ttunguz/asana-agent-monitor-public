# Asana Monitor : Task Title Update Improvements

## Summary
Enhanced the Asana monitor agent to automatically update task titles to be more descriptive after processing, including better handling of timeout & error cases.

## Key Changes

### 1. Enhanced Error & Timeout Handling
- **Now updates titles even on workflow failures** (lines 472, 295 in `agent_monitor.rb`)
- **Timeout-specific title formatting** : Tasks that timeout now get prefixed with `⏱️ Timeout :` followed by extracted context
- **Error-specific title formatting** : Failed tasks get prefixed with `❌` to make them easy to identify

### 2. New Context Extraction Method
Added `extract_context_from_notes()` method (lines 614-675) that intelligently extracts task context from notes:
- **Domain/company detection** : Finds domains like `startup.com`, `acme.io`, `company.ai`
- **Action verb extraction** : Detects patterns like "research startup.com" → "Research startup.com"
- **Email address detection** : Converts `user@example.com` → "Email to User"
- **URL extraction** : Extracts domain from URLs for cleaner titles
- **Meaningful line extraction** : Grabs first substantive line from notes (10-100 chars)
- **Action patterns** : Finds "research X", "analyze Y", "create Z" patterns

### 3. Enhanced Workflow Title Extraction
Improved `extract_title_from_workflow()` method (lines 695-798) with new patterns:
- **Market map operations** : Detects market map tasks & extracts context
- **VCBench analysis** : Identifies VCBench tasks & formats appropriately
- **Action verb patterns** : Generic patterns for analyze/draft/create/search/update actions
- **Better email detection** : Extracts recipient names & subjects more reliably

### 4. Improved Title Generation Logic
Enhanced `generate_descriptive_title()` method (lines 529-612) with:
- **Error/timeout context extraction** : Even failed tasks get descriptive titles
- **Fallback hierarchy** :
  1. Workflow-specific patterns (market map, email, research, etc.)
  2. Error/timeout context from notes
  3. First meaningful line from notes
  4. Result summary from workflow output
  5. Enhanced current title with context

## Title Format Examples

### Before (Generic Titles)
- "Task"
- "Research"
- "Email"
- "Create"
- "Update"

### After (Descriptive Titles)
**Successful workflows:**
- "Research : acme.com"
- "Market Map : AI Infrastructure"
- "Email : Meeting follow-up"
- "VCBench Analysis : startup.io"
- "Company Review : example.com"
- "Summary : techcrunch.com"

**Failed/timeout workflows:**
- "⏱️ Timeout : Research acme.com"
- "⏱️ Timeout : Market Map Generation"
- "❌ Research startup.com" (for other errors)
- "❌ Failed : Email draft" (fallback)

## Benefits

1. **Easier task identification** : Know what each task was about at a glance
2. **Better error tracking** : Failed & timeout tasks are clearly marked
3. **Improved workflow** : No need to open tasks to understand their purpose
4. **Automatic categorization** : Titles are consistently formatted by task type
5. **Context preservation** : Even failed tasks retain information about what was attempted

## Technical Details

### Execution Flow
1. Task processed by workflow (success or failure)
2. `update_task_title()` called with task & result
3. `generate_descriptive_title()` analyzes task notes, workflow result & error
4. Title extracted using multiple strategies (workflow patterns → error context → general extraction)
5. Title cleaned (removes markdown, URLs, special chars)
6. Title updated via Asana API (bypassing TaskAPI safety checks since monitor handles all team tasks)

### Safety Features
- **Length limits** : Titles capped at 120 chars (Asana limit is ~1024)
- **Preserve existing descriptive titles** : Titles >50 chars that aren't generic are kept
- **Clean formatting** : Removes markdown, emoji, URLs for cleaner display
- **Error handling** : Gracefully handles API failures without breaking workflow

## Testing Recommendations

1. **Test with timeout scenarios** : Create a task that will timeout & verify title shows context
2. **Test with various task types** : Research, market map, email, VCBench, general tasks
3. **Test error handling** : Force failures & verify titles are still updated
4. **Test generic vs descriptive titles** : Verify logic doesn't overwrite good titles
5. **Monitor logs** : Check that title updates are logged & successful

## Configuration

No configuration changes needed. The improvements work automatically for all tasks processed by the agent monitor.

To verify title updates are working:
```bash
tail -f /Users/tomasztunguz/Documents/coding/asana-agent-monitor/logs/agent-error.log | grep "Updating task title"
```

## Next Steps (Optional Enhancements)

1. **Add more workflow patterns** : Expand `extract_title_from_workflow()` with new patterns as needed
2. **Improve AI-based title generation** : Use LLM to generate titles for complex tasks
3. **User preferences** : Allow customization of title formats per user/project
4. **Analytics** : Track which title patterns are most common & effective
