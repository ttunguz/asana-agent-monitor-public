# Asana Monitor Update : December 7, 2025

## What Changed

Updated the Asana monitor agent to **ALWAYS update task titles** after processing, including for timeouts, errors & exceptions.

## Why This Matters

Based on the conversation history showing repeated "Workflow timeout after 30 minutes" errors, tasks were not consistently getting descriptive titles. Now **every task** will have a descriptive title showing what was attempted, even if the workflow fails.

## Key Improvements

### 1. Title Updates on ALL Failures
- ✅ Success : Title updated
- ✅ Timeout : Title updated with ⏱️ prefix
- ✅ Error : Title updated with ❌ prefix
- ✅ Exception : Title updated even when workflow crashes

### 2. Better Context Extraction
- Detects domains ("research acme.com" → "Research acme.com")
- Extracts emails ("email to john@example.com" → "Email to John")
- Finds URLs ("summarize https://site.com" → "Summary : site.com")
- Captures partial progress ("Completed 2/5 steps" → "⏱️ Timeout (2/5 steps)")

### 3. No Silent Failures
- Multiple layers of error handling
- Graceful fallbacks if title extraction fails
- Enhanced logging for debugging

## Example Title Updates

### Before This Update
```
Task
Research
Email
Draft
```

### After This Update

**Timeout cases:**
```
⏱️ Timeout : Research acme.com
⏱️ Timeout (2/3 steps)
⏱️ Workflow timeout : Article from techcrunch.com
```

**Error cases:**
```
❌ Research startup.com
❌ Failed : Email to founder
❌ Add company example.com to Attio
```

**Success cases (unchanged):**
```
Research : acme.com
Market Map : AI Infrastructure
Email : Meeting follow-up
VCBench Analysis : startup.io
```

## Files Changed

1. **`lib/agent_monitor.rb`**
   - Line 475, 295 : Removed conditional on title updates for failures
   - Line 482-487, 302-307 : Added exception handling for title updates
   - Line 538-541 : Enhanced logic to ALWAYS update on errors
   - Line 569 : Better timeout detection
   - Line 496 : Added logging for skipped updates

2. **Test files added:**
   - `test_title_update_simple.rb` : Helper method tests
   - `test_title_update_comprehensive.rb` : Full integration tests

3. **Documentation:**
   - `TITLE_UPDATE_ENHANCEMENTS_DEC2025.md` : Detailed technical documentation
   - `UPDATE_SUMMARY_DEC7.md` : This file (quick reference)

## Verification

To verify the updates are working:

```bash
# Watch for title updates in logs
tail -f logs/agent-error.log | grep "Updating task title"

# Check for skipped updates (if debugging)
tail -f logs/agent-error.log | grep "Skipping title update"
```

## What This DOESN'T Fix

This update improves **task visibility & debugging**, but doesn't fix the underlying workflow timeout issue. For that, you may need to:
- Increase workflow timeout limits
- Break complex workflows into smaller steps
- Investigate why workflows are taking >30 minutes

## Next Steps

1. ✅ **Deploy the update** : Changes are ready in `lib/agent_monitor.rb`
2. ✅ **Monitor logs** : Watch for title updates on next workflow run
3. ✅ **Review tasks** : Check Asana for descriptive titles on failed tasks
4. **Investigate timeouts** : Use the descriptive titles to identify patterns in timeout cases

## Questions?

- **Why do titles matter?** : Makes it easier to identify & debug failed tasks
- **Will this slow down processing?** : No, title updates are quick API calls
- **What if title extraction fails?** : Multiple fallbacks ensure some title is always generated
- **Can I customize title formats?** : Yes, edit `extract_title_from_workflow` method in `agent_monitor.rb`

---

**Status** : ✅ Ready to deploy
**Breaking Changes** : None
**Configuration Required** : None
