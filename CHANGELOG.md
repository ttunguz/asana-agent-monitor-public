# Changelog

All notable changes to the Asana AI Agent Monitor project.

## [Unreleased] - 2025-12-14

### Added
- **Comprehensive Documentation**
  - Created `docs/ARCHITECTURE.md` with detailed system design
  - Added workflow diagrams (Mermaid source + PNG renders)
  - Added architecture component diagrams
  - Created `docs/render_diagram.sh` for regenerating diagrams
  - Updated `README.md` with professional formatting, examples & badges

- **Multi-Provider LLM Support**
  - Google Gemini client (`lib/llm/gemini_client.rb`)
  - Anthropic Claude client (`lib/llm/claude_client.rb`)
  - OpenAI GPT client (`lib/llm/openai_client.rb`)
  - Perplexity AI client (`lib/llm/perplexity_client.rb`)
  - Factory pattern for easy provider switching (`lib/llm/base_client.rb`)

- **YAML Configuration System**
  - Environment variable substitution (`${ASANA_API_KEY}`)
  - Multi-provider AI configuration
  - Workflow keyword customization
  - Comprehensive validation with clear error messages

- **Generic Workflows**
  - General search workflow (shopping, product recommendations)
  - Article summary workflow (URL content summarization)
  - Email draft workflow (email composition)
  - Newsletter summary workflow (newsletter processing)
  - Open URL workflow (link handling)

### Removed
- **Theory Ventures-Specific Code**
  - Removed `lib/workflows/company_research.rb` (Theory-specific CRM integration)
  - Removed `lib/workflows/theorymcp_bridge.rb` (Theory MCP API integration)
  - Removed hardcoded Theory Ventures project GIDs
  - Removed hardcoded user IDs

### Changed
- **Parameterization**
  - All configuration moved to `config/config.yml`
  - API keys managed via environment variables
  - Project GIDs, workspace GIDs configurable per deployment
  - User IDs mapped via config (no hardcoding)

- **Graceful Degradation**
  - Made Code Mode APIs optional (agent works without them)
  - Added direct Asana API fallback methods
  - No external dependencies for core functionality

- **Documentation**
  - Professional README with badges, examples & troubleshooting
  - Deployment guides (macOS launchd, Linux systemd, Docker)
  - Extension guides (adding workflows & LLM providers)
  - Quick start guide (5-minute setup)

## [1.0.0] - Initial Release

### Core Features
- Asana task monitoring daemon
- Multi-turn conversation support via comments
- LLM-powered workflow routing
- Processed task tracking (prevents duplicates)
- Comment monitoring for interactive responses

### Architecture
- KeepAlive daemon (not cron job)
- Polls Asana every 60 seconds (configurable)
- Routes tasks to workflows based on keywords
- Creates result tasks for user
- Adds summary comments to original tasks

### Workflows
- General search (web research, product recommendations)
- Article summary (URL content extraction)
- Email draft (email composition)
- Newsletter summary (newsletter processing)
- Open URL (link handling)

## Migration Notes

### For Theory Ventures Users

The original private version (`~/Documents/coding/asana-agent-monitor`) remains unchanged. This open-source version (`~/Documents/coding/asana-agent-monitor-oss`) is a cleaned, parameterized fork.

To migrate:
1. Copy `config/config.example.yml` to `config/config.yml`
2. Fill in your Asana API key, workspace GID, project GID
3. Enable at least one AI provider (Gemini recommended)
4. Customize workflow keywords if needed
5. Run `ruby bin/asana_agent`

### Breaking Changes

- **Configuration**: All hardcoded values must be moved to `config.yml`
- **Code Mode APIs**: Now optional (agent works without them)
- **Workflows**: Theory-specific workflows removed (company_research, theorymcp_bridge)

## Security

### Recommended Practices

- **Never commit `config.yml`** (use `config.example.yml` as template)
- **Use environment variables** for API keys (syntax: `${VAR_NAME}`)
- **Restrict file permissions**: `chmod 600 config/config.yml`
- **Rotate API keys** regularly
- **Use separate API keys** per environment (dev, staging, prod)

## Credits

- Original concept & implementation: Tom Tunguz
- Open-source adaptation: December 2025
- Built with Ruby, Asana API, Google Gemini, Anthropic Claude, OpenAI, Perplexity
