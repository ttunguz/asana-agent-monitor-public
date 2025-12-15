# Asana Monitor : Gemini vs Claude Execution Status

## Current Configuration (December 9, 2025)

### Execution Mode : **Claude-First (Dec 9, 2025)**
The system uses **Claude** as the primary executor with Gemini as fallback.
Switched from Gemini-first due to 100% failure rate on Dec 9 (Issue #12362).

## Status Summary

### ✅ Claude Code - **PRIMARY**
- MCP tools (Theory MCP) work correctly
- Model : `claude-sonnet-4-5-20250929`
- Flags : `--dangerously-skip-permissions` for daemon mode
- **Success rate** : High - handles all prompt sizes reliably

### ⚠️ Gemini - **FALLBACK (disabled until Issue #12362 fixed)**
- **Version** : 0.21.0-nightly.20251209 (or later)
- **Installation** : `npm install -g @google/gemini-cli@nightly`
- **MCP Support** : ✅ Works for simple prompts, ❌ hangs on complex/large prompts
- **Known Issue** : GitHub #12362 - hangs on large stdin prompts in headless mode
- **MCP Trust** : All servers configured with `"trust": true`
- **Status** : 0/12 tasks succeeded on Dec 9, 2025 - all timed out

## MCP Timeout Fix (Dec 2025)

### Background
GitHub Issues #7324 & #6763 reported that Gemini CLI was enforcing a hard-coded 60s timeout on MCP tool calls, ignoring user configuration.

### Resolution
- **PR #7661** ("Simplify MCP server timeout configuration") merged Sept 3, 2025
- **Nightly builds** (0.21.0+) include the fix
- **HTTP-based MCP** (like theorymcp) now works correctly

### Test Results (Dec 9, 2025)
| Test | Result | Time |
|------|--------|------|
| Simple prompt (no MCP) | ✅ PASS | ~5s |
| MCP company search (theorymcp) | ✅ PASS | ~30s |
| MCP company lookup | ✅ PASS | ~25s |

## Configuration

### Environment Variables
- `ASANA_MONITOR_CLAUDE_FIRST` : Controls execution priority
  - `false` (or unset) : **Gemini executes first (Default)**
  - `true` : Claude executes first

### File Locations
- Main workflow : `lib/workflows/gemini_code.rb`
- Claude config : `~/.claude/`
- Gemini config : `~/.gemini/`
- MCP OAuth tokens : `~/.gemini/mcp-oauth-tokens.json`

## How to Test

### Test Gemini with MCP :
```bash
# Simple prompt
echo "What is 2+2?" | gemini -m gemini-3-pro-preview --yolo

# MCP tool call
echo "Use theorymcp to search for company 'stripe'" | gemini -m gemini-3-pro-preview --yolo
```

### Test Claude (fallback) :
```bash
echo "What is 2+2?" | claude -p --model claude-sonnet-4-5-20250929 --dangerously-skip-permissions
```

## To Switch Execution Modes

### Use Gemini-first (Default) :
```bash
export ASANA_MONITOR_CLAUDE_FIRST=false  # or just don't set it
```

### Force Claude-first :
```bash
export ASANA_MONITOR_CLAUDE_FIRST=true
```

## Upgrade Instructions

To get the MCP fix, install the nightly build :
```bash
npm install -g @google/gemini-cli@nightly
gemini --version  # Should show 0.21.0-nightly or later
```

## Known Gemini CLI Issues (Dec 2025)

### Issue #12362 : Large Prompt Hang in Headless Mode
- **Status** : OPEN
- **Impact** : Gemini hangs indefinitely when receiving large prompts via stdin
- **Workaround** : 5-minute timeout with Claude fallback

### Issue #6715 : Subprocess Stdin Hang
- **Status** : CLOSED (fixed)
- **Resolution** : Using pipe workaround in our implementation

### Issue #6103 : Post-Completion Hang
- **Status** : Stale
- **Impact** : Occasional hangs after completing a response

### Issue #2025 : Thinking Indefinitely
- **Status** : P1 Priority
- **Impact** : Model sometimes enters infinite thinking loop

## MCP Trust Configuration

All MCP servers in `~/.gemini/settings.json` now have `"trust": true` :
- `theorymcp` : HTTP-based Theory MCP
- `linear` : Linear issue tracking
- `duckdb` : DuckDB database access
- `github` : GitHub integration

This enables auto-approval of tool executions without user confirmation.
