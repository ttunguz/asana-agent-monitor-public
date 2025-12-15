# Domain Extraction Fix for Task Renaming

## Problem
The task renaming logic was creating malformed titles like:
- "Company Review : etc.)"
- "Company Review : ]("
- "Company Review : (omni.co)"
- "Company Review : "stealthco.com""
- "Company Review : (e.g.,"

## Root Cause
The regex pattern `(\S+\.\S+)` was too greedy - `\S+` matches ANY non-whitespace characters, including:
- Quotes: `"`
- Parentheses: `(`, `)`
- Brackets: `[`, `]`
- Commas: `,`
- And other punctuation

This caused domain extraction to include surrounding punctuation from task notes.

## Solution
Changed all domain extraction patterns from `(\S+\.\S+)` to `([a-z0-9.-]+\.[a-z]{2,})`

This pattern:
- `[a-z0-9.-]+` - Only matches valid domain characters (alphanumeric, hyphens, dots)
- `\.` - Requires a dot separator
- `[a-z]{2,}` - Requires at least 2 letter TLD (e.g., .com, .io, .ai)

## Files Changed
- `lib/agent_monitor.rb`
  - Line 813: Research workflow domain extraction
  - Line 820: Attio/CRM workflow domain extraction
  - Line 831: Market map domain extraction
  - Line 734: Context extraction from notes
  - Line 883: VCBench domain extraction

## Verification
All test cases pass:
```
Input: attio "omni.co",
  Old pattern: "omni.co\","  ❌
  New pattern: "omni.co"     ✅

Input: company (spatial.ai)
  Old pattern: "spatial.ai)" ❌
  New pattern: "spatial.ai"  ✅

Input: etc.)
  Old pattern: "etc.)"       ❌
  New pattern: nil           ✅
```

## Testing
Run the test script:
```bash
ruby /Users/tomasztunguz/Documents/coding/asana-agent-monitor/test_domain_extraction.rb
```

## Impact
- Task titles will now show clean domain names without surrounding punctuation
- Improves readability in Asana task lists
- Prevents confusion about what domain/company is being reviewed
