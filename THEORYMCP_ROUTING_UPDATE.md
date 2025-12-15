# Theory MCP Execution Update Summary

**Date:** December 3, 2025
**Status:** UPDATED (Gemini-First with Smart Routing)

## Change Implemented

Modified the execution logic to intelligently route MCP-related tasks to Claude, preventing Gemini failures/hangs.

### The Logic (`gemini_code.rb`)

1. **Detection:**
   The workflow now checks if the task is classified as `:company_research` AND contains keywords like "market map" or "theorymcp".

2. **Smart Routing:**
   - **Standard Tasks:** Default to Gemini -> Fallback to Claude (Gemini-First mode).
   - **MCP Tasks:** Force Claude -> NO FALLBACK to Gemini.
     - We skip Gemini fallback because it is known to hang on MCP tool calls.

3. **Prompt Updates:**
   - Updated `CompanyResearch` and `General` templates to allow usage of `mcp__theorymcp__*` tools when executing via Claude.
   - Removed the "Theory MCP is NOT accessible" strict warning.

### Why This Fixes "Fail Over to Gemini"

Previously, if we were in Gemini-first mode (default):
1. Gemini would try (and fail/hang on MCP).
2. Or if we manually routed to Claude and it failed, we might have fallen back to Gemini.

Now:
1. If MCP is detected, we START with Claude.
2. If Claude fails, we STOP (we do not "fail over to Gemini" which would just hang).

### Verification
- **Scenario A (Normal):** "Research Stripe" -> Gemini (Primary) -> Claude (Fallback)
- **Scenario B (MCP):** "Add Stripe to Market Map" -> Claude (Forced) -> Stop (if fail)

## Files Modified
- `lib/workflows/gemini_code.rb`
- `lib/prompt_templates/company_research.rb`
- `lib/prompt_templates/general.rb`
