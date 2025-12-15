# Theory MCP Integration Fix Summary

**Date:** December 3, 2025
**Issue:** Asana monitor agent couldn't use Theory MCP for market map operations
**Status:** RESOLVED

## Problem Identified

The asana-agent-monitor was instructing Gemini/Claude to use `TheoryMCPAPI` for market map operations, but this API wasn't accessible:

1. **Incorrect Instructions**: The `gemini_code.rb` workflow was referencing `TheoryMCPAPI.add_to_market_map()`
2. **MCP Server Limitation**: Theory MCP server (mcp__theorymcp__*) is only accessible from Claude Code, not from the Gemini agent
3. **Confusion**: There's a Ruby wrapper (`theory_mcp_api.rb`) that exists but uses NotionAPI underneath, not the actual MCP server

## Solution Implemented

Updated `/Users/tomasztunguz/Documents/coding/asana-agent-monitor/lib/workflows/gemini_code.rb`:

### Before (lines 253-268):
```ruby
- TheoryMCPAPI.add_to_market_map(notion_link: 'https://notion.so/...', domains: ['acme.com'])
- TheoryMCPAPI.quick_add(notion_link: 'https://notion.so/...', domain: 'acme.com')
```

### After:
```ruby
- MarketMapAPI.generate(domains: ['stripe.com', 'plaid.com'], skip_forum: true)
  # Generates market map analysis
- AttioAPI.find_or_create(domain: 'startup.com', name: 'Startup', source: 'referral')
  # Creates companies in Attio
- Added note: "IMPORTANT: The Theory MCP server is only accessible from Claude, not from this agent."
```

## Key Changes

1. **Removed TheoryMCPAPI references** - These don't work from Gemini
2. **Added proper MarketMapAPI usage** - This generates the market map content correctly
3. **Added AttioAPI instructions** - For creating companies in the CRM
4. **Added clarification** - Explaining that Theory MCP is Claude-only

## Testing

1. Created test task in Asana: "Create market map using theorymcp" (ID: 1212296192094092)
2. Added comment to existing "AI Options Trading" task to test the fix
3. Agent should now properly generate market maps using MarketMapAPI

## Architecture Clarification

```
Claude Code (You)
    ├── Can use: mcp__theorymcp__* (native MCP tools)
    └── Can use: Code Mode APIs (EmailAPI, AttioAPI, etc.)

Asana Monitor Agent (Gemini/Claude CLI)
    ├── Can use: Code Mode APIs via Ruby
    ├── Can use: MarketMapAPI, AttioAPI, NotionAPI
    └── CANNOT use: mcp__theorymcp__* (MCP server tools)
```

## Recommendations

1. **For Market Maps from Asana Agent:**
   - Use `MarketMapAPI.generate()` to create content
   - Use `AttioAPI.find_or_create()` to add companies
   - Save content to file/clipboard for manual Notion upload

2. **For Theory MCP Operations:**
   - Only use from Claude Code directly
   - Use `mcp__theorymcp__add_company_to_market_map` for adding to existing maps
   - Use `mcp__theorymcp__create_market_map` for new market maps

## Files Modified

- `/Users/tomasztunguz/Documents/coding/asana-agent-monitor/lib/workflows/gemini_code.rb` (lines 246-277)

## Next Steps

1. Monitor the agent's next run cycle to verify it processes market map tasks correctly
2. Consider creating a bridge API that allows Gemini to trigger Claude Code for MCP operations
3. Document this limitation in the main README for the asana-agent-monitor project