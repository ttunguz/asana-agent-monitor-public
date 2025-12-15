# Open-Source Plan for Asana Agent Monitor

## Executive Summary

This document outlines the work required to make the Asana Agent Monitor open-source and useful for external developers. The project currently has hard-coded paths, Theory-specific workflows, and dependencies on Code Mode APIs. To make it portable, we need to parameterize configuration, abstract AI providers, and provide clear documentation.

**Estimated effort**: 15-20 hours
**Priority**: High (enables community contributions & broader adoption)

---

## 1. Hard-Coded Dependencies to Remove

### 1.1 File Path Dependencies

**Location**: `lib/agent_monitor.rb`

**Hard-coded paths**:
- Line 9: `/Users/tomasztunguz/.gemini/code_mode/task_api` → Remove or make optional
- Line 49: `/Users/tomasztunguz/.gemini/custom_tools_src/secret_manager` → Replace with ENV vars

**Solution**:
```ruby
# BEFORE (lib/agent_monitor.rb:9)
require '/Users/tomasztunguz/.gemini/code_mode/task_api'

# AFTER
# Remove dependency - use native Asana API calls via execute_asana_request()
# OR make it optional:
begin
  require ENV['TASK_API_PATH'] if ENV['TASK_API_PATH']
rescue LoadError
  # TaskAPI not available - fall back to native API
end
```

**Rationale**: External users won't have Code Mode APIs. Provide native Asana API alternative.

---

### 1.2 Configuration Parameterization

**Location**: `config/agent_config.rb`

**Current hard-coded values**:
```ruby
ASANA_PROJECT_GIDS = ['1211959613518208', '1203633898433121']
ASANA_WORKSPACE_GID = '1203633898433095'
ASANA_TEAM_GID = '1204407826411712'
AGENT_NAME = 'Tomasz Tunguz'
ASSIGNEES = {
  'tom' => '1203633898433084',
  'art' => '1205128325411795',
  'lauren' => '1204407991572571'
}
```

**Solution**: Create YAML configuration file

**File**: `config/config.example.yml`
```yaml
# Asana Configuration
asana:
  api_key: ENV['ASANA_API_KEY']  # Required
  project_gids:  # Monitor these projects (required)
    - '1234567890'  # Example project
  workspace_gid: ''  # Your Asana workspace GID (required)
  team_gid: ''  # Optional
  agent_name: 'AI Agent'  # Name shown in comments

# Assignees (User GID mappings)
# Add your own team members here
assignees:
  alice: '1234567890123456'
  bob: '9876543210987654'
  # Add more as needed

# Monitoring Configuration
monitoring:
  check_interval_minutes: 3
  enable_comment_monitoring: true
  comment_monitoring_days: 7
  max_concurrent_workers: 10
  task_timeout: 1800  # 30 minutes

# AI Provider Configuration
ai:
  provider: 'gemini'  # Options: gemini, claude, openai, perplexity
  gemini_api_key: ENV['GEMINI_API_KEY']
  claude_api_key: ENV['CLAUDE_API_KEY']
  openai_api_key: ENV['OPENAI_API_KEY']
  perplexity_api_key: ENV['PERPLEXITY_API_KEY']

# Logging
logging:
  log_dir: './logs'
  log_level: 'info'  # debug, info, warn, error
```

**Load in `config/agent_config.rb`**:
```ruby
require 'yaml'

module AgentConfig
  CONFIG_FILE = ENV['AGENT_CONFIG'] || File.expand_path('../config.yml', __FILE__)

  unless File.exist?(CONFIG_FILE)
    raise "Config file not found: #{CONFIG_FILE}. Copy config.example.yml to config.yml"
  end

  config = YAML.load_file(CONFIG_FILE)

  # Asana Configuration
  ASANA_PROJECT_GIDS = config['asana']['project_gids']
  ASANA_WORKSPACE_GID = config['asana']['workspace_gid']
  ASANA_TEAM_GID = config['asana']['team_gid']
  AGENT_NAME = config['asana']['agent_name']

  # Assignees
  ASSIGNEES = config['assignees'] || {}

  # Monitoring
  CHECK_INTERVAL_MINUTES = config['monitoring']['check_interval_minutes']
  ENABLE_COMMENT_MONITORING = config['monitoring']['enable_comment_monitoring']
  COMMENT_MONITORING_DAYS = config['monitoring']['comment_monitoring_days']
  MAX_CONCURRENT_WORKERS = config['monitoring']['max_concurrent_workers']
  TASK_TIMEOUT = config['monitoring']['task_timeout']

  # AI Provider
  AI_PROVIDER = config['ai']['provider']

  # Logging
  LOG_DIR = File.expand_path(config['logging']['log_dir'])
  LOG_FILE = File.join(LOG_DIR, 'agent.log')
  LOG_LEVEL = config['logging']['log_level'].to_sym
  COMMENT_STATE_FILE = File.join(LOG_DIR, 'processed_comments.json')
end
```

---

## 2. AI Provider Abstraction

### 2.1 Current State

**Multiple AI providers used**:
- `lib/workflows/general_search.rb` → Perplexity API
- `lib/workflows/gemini_code.rb` → Gemini API
- Various workflows → Hard-coded API calls

### 2.2 Solution: Create AI Client Abstraction

**File**: `lib/llm/base_client.rb`
```ruby
# lib/llm/base_client.rb

module LLM
  class BaseClient
    def initialize(provider: nil, api_key: nil)
      @provider = provider || AgentConfig::AI_PROVIDER
      @api_key = api_key || get_api_key_for_provider(@provider)
    end

    def call(prompt, complexity: :standard)
      case @provider.downcase
      when 'gemini'
        gemini_call(prompt, complexity)
      when 'claude'
        claude_call(prompt, complexity)
      when 'openai'
        openai_call(prompt, complexity)
      when 'perplexity'
        perplexity_call(prompt, complexity)
      else
        raise "Unsupported AI provider: #{@provider}"
      end
    end

    private

    def get_api_key_for_provider(provider)
      case provider.downcase
      when 'gemini'
        ENV['GEMINI_API_KEY']
      when 'claude'
        ENV['CLAUDE_API_KEY']
      when 'openai'
        ENV['OPENAI_API_KEY']
      when 'perplexity'
        ENV['PERPLEXITY_API_KEY']
      else
        raise "Unknown provider: #{provider}"
      end
    end

    def gemini_call(prompt, complexity)
      # Existing Gemini implementation
    end

    def claude_call(prompt, complexity)
      # Claude API implementation
    end

    def openai_call(prompt, complexity)
      # OpenAI API implementation
    end

    def perplexity_call(prompt, complexity)
      # Perplexity API implementation (for search workflows)
    end
  end
end
```

**Benefit**: Users can choose their preferred AI provider via config, not code changes.

---

## 3. Workflow Simplification

### 3.1 Remove Theory-Specific Workflows

**Workflows to remove or make optional**:
- `lib/workflows/company_research.rb` → Depends on AttioAPI, Theory MCP
- `lib/workflows/theorymcp_bridge.rb` → Theory-specific

**Workflows to keep (generic & useful)**:
- ✅ `lib/workflows/general_search.rb` → AI-powered web research
- ✅ `lib/workflows/article_summary.rb` → URL summarization
- ✅ `lib/workflows/email_draft.rb` → Email drafting
- ✅ `lib/workflows/newsletter_summary.rb` → Newsletter processing
- ✅ `lib/workflows/gemini_code.rb` → Generic AI workflow with GEPA/DPSY

**Solution**: Create plugin-style workflow system

**File**: `lib/workflows/plugin_loader.rb`
```ruby
module Workflows
  class PluginLoader
    CORE_WORKFLOWS = [
      'general_search',
      'article_summary',
      'email_draft',
      'newsletter_summary',
      'gemini_code'
    ].freeze

    def self.load_workflows
      # Load core workflows
      CORE_WORKFLOWS.each do |workflow|
        require_relative workflow
      end

      # Load custom workflows from config/custom_workflows/ (if present)
      custom_dir = File.expand_path('../../config/custom_workflows', __FILE__)
      if Dir.exist?(custom_dir)
        Dir.glob("#{custom_dir}/*.rb").each { |f| require f }
      end
    end
  end
end
```

**User experience**: Users can add custom workflows by dropping `.rb` files in `config/custom_workflows/`.

---

## 4. Documentation Requirements

### 4.1 README.md Enhancement

**Current**: Theory-specific, assumes Code Mode setup

**New structure**:
```markdown
# Asana Agent Monitor

AI-powered Asana task automation with natural language processing.

## Features
- 🤖 AI-powered task processing with GPT-4, Claude, Gemini, or Perplexity
- 🔍 General web research (shopping, product recommendations, Q&A)
- 📧 Email drafting with context awareness
- 📰 Newsletter summarization
- 🗣️ Comment monitoring & conversation tracking
- 🔌 Plugin system for custom workflows

## Quick Start

### Prerequisites
- Ruby 3.0+
- Asana account & API token
- AI provider (Gemini, Claude, OpenAI, or Perplexity)

### Installation

1. **Clone repository**:
   ```bash
   git clone https://github.com/yourusername/asana-agent-monitor
   cd asana-agent-monitor
   ```

2. **Install dependencies**:
   ```bash
   bundle install
   ```

3. **Configure**:
   ```bash
   cp config/config.example.yml config/config.yml
   # Edit config.yml with your settings
   ```

4. **Set environment variables**:
   ```bash
   export ASANA_API_KEY="your_asana_key"
   export GEMINI_API_KEY="your_ai_key"  # Or CLAUDE_API_KEY, etc.
   ```

5. **Run**:
   ```bash
   ruby bin/monitor.rb
   ```

### Configuration

#### Asana Setup
1. Create a project in Asana for agent tasks
2. Get project GID from URL: `https://app.asana.com/0/PROJECT_GID`
3. Add to `config.yml`:
   ```yaml
   asana:
     project_gids:
       - 'YOUR_PROJECT_GID'
   ```

#### AI Provider
Choose one:
- **Gemini**: Set `GEMINI_API_KEY`
- **Claude**: Set `CLAUDE_API_KEY`
- **OpenAI**: Set `OPENAI_API_KEY`
- **Perplexity**: Set `PERPLEXITY_API_KEY`

Update `ai.provider` in `config.yml`:
```yaml
ai:
  provider: 'gemini'  # or claude, openai, perplexity
```

### Usage

#### Basic Workflow
1. Create a task in your monitored Asana project
2. Add task notes with your request (e.g., "Search for the best Lego sets under $50")
3. Agent processes task automatically (every 3 minutes by default)
4. Agent adds results as a comment

#### Comment Interaction
- Ask follow-up questions by commenting on tasks
- Agent maintains conversation context
- Say "retry" or "redo" to reprocess

### Deployment Options

#### systemd (Linux)
See `docs/DEPLOYMENT.md` for systemd service setup.

#### launchd (macOS)
```bash
cp launchd.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/launchd.plist
```

#### Docker
```bash
docker build -t asana-agent .
docker run -d --env-file .env asana-agent
```

### Custom Workflows

Create custom workflows in `config/custom_workflows/`:

```ruby
# config/custom_workflows/my_workflow.rb
require_relative '../../lib/workflows/base'

module Workflows
  class MyWorkflow < Base
    def execute
      # Your custom logic here
      {
        success: true,
        comment: "✅ Custom workflow completed"
      }
    end
  end
end
```

### Troubleshooting

**Issue**: Agent not processing tasks
- Check `logs/agent.log` for errors
- Verify `ASANA_API_KEY` is set correctly
- Confirm project GID is correct

**Issue**: AI responses failing
- Check AI provider API key is set
- Verify API key has credits/access
- Try different provider in config

### Contributing

See `CONTRIBUTING.md` for development setup and guidelines.

### License

MIT License - see `LICENSE` file.
```

---

### 4.2 Installation Documentation

**File**: `docs/INSTALLATION.md`

**Sections**:
1. System requirements
2. Ruby installation (rbenv, RVM, or system Ruby)
3. Bundler setup
4. Configuration file creation
5. Environment variable setup
6. Asana API token generation
7. AI provider API key setup
8. First run checklist

---

### 4.3 Workflow Documentation

**File**: `docs/WORKFLOWS.md`

**Content**:
```markdown
# Workflow System

## How It Works

The agent routes tasks to workflows based on keywords, task notes, and AI classification.

## Available Workflows

### GeneralSearch
**Trigger keywords**: search for, find me, shopping, buy, recommend
**Purpose**: AI-powered web research & product recommendations
**Example**: "Search for the two best Lego sets under $50"

### ArticleSummary
**Trigger keywords**: summarize, summary, URL in task notes
**Purpose**: Summarize web articles
**Example**: Task with URL in notes

### EmailDraft
**Trigger keywords**: email, draft email, message, write to
**Purpose**: Draft emails with context awareness
**Example**: "Draft email to john@example.com about meeting"

### NewsletterSummary
**Trigger keywords**: newsletter, digest
**Purpose**: Process & summarize newsletters
**Example**: "Summarize this newsletter" (with newsletter content in notes)

### GeminiCode (Default)
**Trigger**: Fallback for unmatched tasks
**Purpose**: Generic AI task processing with GEPA (multi-step) support
**Example**: Any complex task requiring multi-step reasoning

## Creating Custom Workflows

1. Create file in `config/custom_workflows/my_workflow.rb`
2. Extend `Workflows::Base`
3. Implement `execute` method
4. Return hash with `:success`, `:comment`

Example:
```ruby
require_relative '../../lib/workflows/base'

module Workflows
  class MyWorkflow < Base
    def execute
      # Extract data from task
      query = task.notes

      # Process with AI
      result = @llm_client.call("Process this: #{query}")

      # Return result
      {
        success: result[:success],
        comment: "✅ Result: #{result[:output]}"
      }
    rescue => e
      {
        success: false,
        error: e.message,
        comment: "❌ Failed: #{e.message}"
      }
    end
  end
end
```

## Workflow Base Class API

### Available Methods

**Task Access**:
- `task.name` - Task title
- `task.notes` - Task description
- `task.gid` - Asana task ID

**Context**:
- `from_comment?` - True if triggered by comment
- `@comment_text` - Comment text (if from comment)
- `@all_comments` - Full comment history

**Helpers**:
- `log_info(msg)` - Log info message
- `log_error(msg)` - Log error message
- `create_tom_task(title:, notes:)` - Create new task for user
- `@llm_client.call(prompt, complexity:)` - Call AI

### Return Format

```ruby
{
  success: true,  # Boolean
  comment: "✅ Success message",  # String (shown to user)
  error: "Error details"  # Optional (if success: false)
}
```
```

---

## 5. Testing Strategy

### 5.1 Test with Minimal Configuration

**File**: `spec/minimal_config_spec.rb`

**Tests**:
- Agent starts with only `config.yml` (no Code Mode APIs)
- Uses native Asana API calls
- Routes to generic workflows
- Handles missing optional workflows gracefully

### 5.2 Multi-Provider Testing

**File**: `spec/ai_provider_spec.rb`

**Tests**:
- Gemini provider works
- Claude provider works
- OpenAI provider works
- Perplexity provider works
- Graceful fallback if provider fails

### 5.3 Plugin System Testing

**File**: `spec/plugin_loader_spec.rb`

**Tests**:
- Core workflows load correctly
- Custom workflows in `config/custom_workflows/` load
- Invalid workflows are skipped with warning

---

## 6. File Structure Changes

### Before (Theory-specific)
```
asana-agent-monitor/
├── lib/
│   ├── agent_monitor.rb  # Hard-coded paths
│   ├── workflows/
│   │   ├── company_research.rb  # Theory-specific
│   │   ├── theorymcp_bridge.rb  # Theory-specific
│   │   └── ... (generic workflows)
│   └── llm/
│       └── robust_client.rb  # Gemini-only
└── config/
    └── agent_config.rb  # Hard-coded GIDs
```

### After (Open-source ready)
```
asana-agent-monitor/
├── README.md              # Enhanced quick start
├── LICENSE                # MIT License
├── Gemfile                # Ruby dependencies
├── .env.example           # Environment variables template
├── config/
│   ├── config.example.yml      # Configuration template
│   ├── agent_config.rb         # Loads from YAML
│   └── custom_workflows/       # User workflows (optional)
│       └── .gitkeep
├── lib/
│   ├── agent_monitor.rb        # No hard-coded paths
│   ├── workflow_router.rb      # Simplified routing
│   ├── comment_tracker.rb      # Keep as-is
│   ├── llm/
│   │   ├── base_client.rb      # Multi-provider support
│   │   ├── gemini_client.rb
│   │   ├── claude_client.rb
│   │   ├── openai_client.rb
│   │   └── perplexity_client.rb
│   └── workflows/
│       ├── base.rb             # Base workflow class
│       ├── general_search.rb   # Keep (generic)
│       ├── article_summary.rb  # Keep (generic)
│       ├── email_draft.rb      # Keep (generic)
│       ├── newsletter_summary.rb # Keep (generic)
│       ├── gemini_code.rb      # Keep (generic)
│       └── plugin_loader.rb    # NEW (loads custom workflows)
├── bin/
│   └── monitor.rb              # Entry point
├── docs/
│   ├── INSTALLATION.md         # Detailed setup
│   ├── WORKFLOWS.md            # Workflow documentation
│   ├── DEPLOYMENT.md           # systemd/launchd/Docker
│   └── CONTRIBUTING.md         # Development guide
├── spec/
│   ├── minimal_config_spec.rb
│   ├── ai_provider_spec.rb
│   └── plugin_loader_spec.rb
└── examples/
    ├── systemd.service         # Linux deployment
    ├── launchd.plist           # macOS deployment
    └── custom_workflow.rb      # Example custom workflow
```

---

## 7. Implementation Phases

### Phase 1: Core Parameterization (5-7 hours)
1. ✅ Create `config.example.yml`
2. ✅ Update `config/agent_config.rb` to load from YAML
3. ✅ Remove hard-coded paths from `lib/agent_monitor.rb`
4. ✅ Make Code Mode APIs optional (graceful fallback)
5. ✅ Test with minimal config

### Phase 2: AI Provider Abstraction (3-4 hours)
1. ✅ Create `lib/llm/base_client.rb`
2. ✅ Implement Gemini client
3. ✅ Implement Claude client
4. ✅ Implement OpenAI client
5. ✅ Implement Perplexity client
6. ✅ Update workflows to use `base_client`

### Phase 3: Workflow Simplification (2-3 hours)
1. ✅ Create `lib/workflows/plugin_loader.rb`
2. ✅ Remove Theory-specific workflows to `examples/` (for reference)
3. ✅ Test core workflows work standalone
4. ✅ Add custom workflow example

### Phase 4: Documentation (4-5 hours)
1. ✅ Write new `README.md`
2. ✅ Create `docs/INSTALLATION.md`
3. ✅ Create `docs/WORKFLOWS.md`
4. ✅ Create `docs/DEPLOYMENT.md`
5. ✅ Add `examples/` directory with deployment templates

### Phase 5: Testing & Release (1-2 hours)
1. ✅ Test on fresh Ubuntu VM
2. ✅ Test on fresh macOS install
3. ✅ Create GitHub repository
4. ✅ Add CI/CD (GitHub Actions)
5. ✅ Tag v1.0.0 release

**Total estimated time**: 15-20 hours

---

## 8. Environment Variables Reference

### Required
- `ASANA_API_KEY` - Asana Personal Access Token

### AI Providers (Choose One)
- `GEMINI_API_KEY` - Google Gemini API
- `CLAUDE_API_KEY` - Anthropic Claude API
- `OPENAI_API_KEY` - OpenAI GPT API
- `PERPLEXITY_API_KEY` - Perplexity AI (for search workflows)

### Optional
- `AGENT_CONFIG` - Path to custom config file (default: `config/config.yml`)
- `USE_ROBUST_AI` - Enable robust AI workflow (default: `false`)

**File**: `.env.example`
```bash
# Required
ASANA_API_KEY=your_asana_personal_access_token

# AI Provider (choose one or more)
GEMINI_API_KEY=your_gemini_key
CLAUDE_API_KEY=your_claude_key
OPENAI_API_KEY=your_openai_key
PERPLEXITY_API_KEY=your_perplexity_key

# Optional
AGENT_CONFIG=config/config.yml
USE_ROBUST_AI=false
```

---

## 9. Breaking Changes for Theory Setup

### What Breaks?
- Hard-coded paths to Code Mode APIs → Need to set `TASK_API_PATH` env var (optional)
- Hard-coded Asana GIDs → Need to update `config.yml`
- Hard-coded assignee mappings → Need to update `config.yml`

### Migration Path (for Theory Ventures)
1. Create `config/config.yml` from template
2. Copy current values from `agent_config.rb`
3. Set environment variable: `export TASK_API_PATH=/Users/tomasztunguz/.gemini/code_mode/task_api`
4. Restart agent

**No code changes needed** - just configuration.

---

## 10. Success Criteria

### Functional Requirements
- ✅ Agent runs without Code Mode APIs
- ✅ Works with any AI provider (Gemini, Claude, OpenAI, Perplexity)
- ✅ User can configure via YAML (no code changes)
- ✅ Custom workflows can be added as plugins
- ✅ Deployment guides for Linux & macOS

### Documentation Requirements
- ✅ README with quick start (<5 minutes to first run)
- ✅ Installation guide (detailed setup)
- ✅ Workflow documentation (how to create custom workflows)
- ✅ Deployment options (systemd, launchd, Docker)

### Testing Requirements
- ✅ Works on fresh Ubuntu 22.04 install
- ✅ Works on fresh macOS install
- ✅ All core workflows functional
- ✅ Multiple AI providers tested

---

## 11. Future Enhancements (Post-Release)

### Plugin Marketplace
- NPM-style plugin installation
- Community-contributed workflows
- Workflow discovery & search

### Web UI
- Dashboard for monitoring tasks
- Configuration editor
- Log viewer

### Advanced Features
- Multi-language support
- Voice input/output
- Mobile app integration

---

## Summary

**To make Asana Agent Monitor open-source:**

1. **Parameterize everything** - API keys, project IDs, user IDs via `config.yml`
2. **Remove Code Mode dependencies** - Use native Asana API or make optional
3. **Abstract AI providers** - Support Gemini, Claude, OpenAI, Perplexity
4. **Simplify workflows** - Remove Theory-specific, keep generic ones
5. **Document thoroughly** - Installation, configuration, customization
6. **Provide examples** - systemd, launchd, Docker deployment

**Estimated effort**: 15-20 hours over 5 phases

**Minimal changes for basic functionality**:
- Extract config to YAML (2-3 hours)
- Remove Code Mode deps (1-2 hours)
- Abstract AI client (2-3 hours)
- Write documentation (3-4 hours)

**Result**: A portable, well-documented Asana automation framework that works for any team.
