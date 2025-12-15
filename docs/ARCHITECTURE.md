# Asana AI Agent - Architecture Overview

## System Flow Diagram

```mermaid
graph TB
    Start([Agent Daemon Starts]) --> LoadConfig[Load config.yml]
    LoadConfig --> ValidateConfig{Validate<br/>Configuration}
    ValidateConfig -->|Invalid| ConfigError[Show Configuration Errors]
    ValidateConfig -->|Valid| InitMonitor[Initialize Agent Monitor]

    InitMonitor --> InitLLM[Initialize LLM Clients]
    InitLLM --> PollLoop{Poll Asana Tasks<br/>Every N Seconds}

    PollLoop --> FetchTasks[Fetch Incomplete Tasks<br/>from Project]
    FetchTasks --> FilterProcessed{Filter Already<br/>Processed Tasks}

    FilterProcessed --> CheckNewTasks{New Tasks<br/>Found?}
    CheckNewTasks -->|No| CheckComments{Comment<br/>Monitoring?}
    CheckNewTasks -->|Yes| RouteWorkflow[Route to Workflow]

    CheckComments -->|Disabled| Sleep[Sleep Poll Interval]
    CheckComments -->|Enabled| FetchComments[Fetch New Comments]
    FetchComments --> CheckNewComments{New Comments?}
    CheckNewComments -->|No| Sleep
    CheckNewComments -->|Yes| RouteComment[Route Comment to Workflow]

    RouteWorkflow --> ClassifyTask[Classify Task Intent<br/>Using LLM]
    RouteComment --> ClassifyTask

    ClassifyTask --> SelectWorkflow{Select Workflow<br/>Based on Keywords}

    SelectWorkflow -->|search, find, shopping| GeneralSearch[General Search Workflow]
    SelectWorkflow -->|summarize, summary| ArticleSummary[Article Summary Workflow]
    SelectWorkflow -->|email, draft| EmailDraft[Email Draft Workflow]
    SelectWorkflow -->|newsletter| NewsletterSummary[Newsletter Summary Workflow]
    SelectWorkflow -->|url, link| OpenURL[Open URL Workflow]

    GeneralSearch --> ExecuteWorkflow[Execute Workflow<br/>with Selected LLM]
    ArticleSummary --> ExecuteWorkflow
    EmailDraft --> ExecuteWorkflow
    NewsletterSummary --> ExecuteWorkflow
    OpenURL --> ExecuteWorkflow

    ExecuteWorkflow --> LLMProvider{Which LLM<br/>Provider?}

    LLMProvider -->|Configured| Gemini[Gemini Client]
    LLMProvider -->|Configured| Claude[Claude Client]
    LLMProvider -->|Configured| OpenAI[OpenAI Client]
    LLMProvider -->|Configured| Perplexity[Perplexity Client]

    Gemini --> GenerateResponse[Generate AI Response]
    Claude --> GenerateResponse
    OpenAI --> GenerateResponse
    Perplexity --> GenerateResponse

    GenerateResponse --> CreateResultTask[Create Result Task<br/>for User]
    CreateResultTask --> AddComment[Add Summary Comment<br/>to Original Task]
    AddComment --> MarkProcessed[Mark Task as Processed<br/>in processed_tasks.json]

    MarkProcessed --> Sleep
    Sleep --> PollLoop

    ConfigError --> Exit([Exit with Error])

    style Start fill:#90EE90
    style Exit fill:#FFB6C1
    style ClassifyTask fill:#FFE4B5
    style ExecuteWorkflow fill:#FFE4B5
    style GenerateResponse fill:#87CEEB
    style CreateResultTask fill:#DDA0DD
```

## Component Architecture

```mermaid
graph LR
    subgraph "Configuration Layer"
        ConfigYML[config.yml]
        EnvVars[Environment Variables]
        ConfigYML --> AgentConfig[AgentConfig Module]
        EnvVars --> AgentConfig
    end

    subgraph "Core Agent"
        AgentConfig --> AgentMonitor[AgentMonitor]
        AgentMonitor --> WorkflowRouter[WorkflowRouter]
        AgentMonitor --> TaskTracker[ProcessedTasksTracker]
    end

    subgraph "LLM Layer"
        WorkflowRouter --> BaseClient[BaseClient Factory]
        BaseClient --> GeminiClient[GeminiClient]
        BaseClient --> ClaudeClient[ClaudeClient]
        BaseClient --> OpenAIClient[OpenAIClient]
        BaseClient --> PerplexityClient[PerplexityClient]
    end

    subgraph "Workflow Layer"
        WorkflowRouter --> GeminiCode[GeminiCode Workflow]
        GeminiCode --> GeneralSearch[GeneralSearch]
        GeminiCode --> ArticleSummary[ArticleSummary]
        GeminiCode --> EmailDraft[EmailDraft]
        GeminiCode --> NewsletterSummary[NewsletterSummary]
        GeminiCode --> OpenURL[OpenURL]
    end

    subgraph "External APIs"
        GeneralSearch --> AsanaAPI[Asana API]
        ArticleSummary --> AsanaAPI
        EmailDraft --> AsanaAPI
        NewsletterSummary --> AsanaAPI
        OpenURL --> AsanaAPI

        GeminiClient --> GeminiAPI[Google Gemini API]
        ClaudeClient --> ClaudeAPI[Anthropic API]
        OpenAIClient --> OpenAIAPI[OpenAI API]
        PerplexityClient --> PerplexityAPI[Perplexity API]
    end

    style AgentConfig fill:#FFE4B5
    style BaseClient fill:#87CEEB
    style GeminiCode fill:#DDA0DD
    style AsanaAPI fill:#90EE90
```

## Workflow Execution Details

### General Search Workflow

```mermaid
sequenceDiagram
    participant User
    participant Asana
    participant Agent
    participant LLM

    User->>Asana: Create Task "Search for best headphones under $200"
    Asana->>Agent: Poll: New incomplete task found
    Agent->>Agent: Extract search query from task notes/comments
    Agent->>LLM: Send query with "general search" context
    LLM->>Agent: Return search results with recommendations
    Agent->>Asana: Create result task for user with findings
    Agent->>Asana: Add summary comment to original task
    Agent->>Agent: Mark task as processed
```

### Article Summary Workflow

```mermaid
sequenceDiagram
    participant User
    participant Asana
    participant Agent
    participant LLM
    participant Web

    User->>Asana: Create Task "Summarize https://example.com/article"
    Asana->>Agent: Poll: New incomplete task found
    Agent->>Agent: Extract URL from task
    Agent->>Web: Fetch article content
    Web->>Agent: Return HTML/text
    Agent->>LLM: Send article with "summarize" prompt
    LLM->>Agent: Return structured summary
    Agent->>Asana: Create result task with summary
    Agent->>Asana: Add brief summary to original task
    Agent->>Agent: Mark task as processed
```

## Configuration Flow

```mermaid
graph TD
    Start([Start Agent]) --> CheckConfig{config.yml<br/>exists?}
    CheckConfig -->|No| ShowError[Show Error:<br/>Copy config.example.yml]
    CheckConfig -->|Yes| LoadYAML[Load YAML File]

    LoadYAML --> ProcessERB[Process ERB Templates<br/>for ${ENV_VAR} substitution]
    ProcessERB --> ValidateAsana{Validate Asana<br/>Settings}

    ValidateAsana -->|Missing| ShowAsanaError[Error: api_key, workspace_gid,<br/>project_gid required]
    ValidateAsana -->|Valid| ValidateAI{Validate AI<br/>Providers}

    ValidateAI -->|None Enabled| ShowAIError[Error: Enable at least<br/>one AI provider]
    ValidateAI -->|Valid| ValidateKeys{Validate API Keys<br/>for Enabled Providers}

    ValidateKeys -->|Missing| ShowKeyError[Error: API key required<br/>for enabled provider]
    ValidateKeys -->|Valid| ConfigReady[Configuration Ready]

    ShowError --> Exit([Exit])
    ShowAsanaError --> Exit
    ShowAIError --> Exit
    ShowKeyError --> Exit

    ConfigReady --> InitAgent[Initialize Agent Monitor]

    style Start fill:#90EE90
    style ConfigReady fill:#90EE90
    style Exit fill:#FFB6C1
```

## LLM Provider Selection

The agent supports multiple LLM providers with automatic fallback:

1. **Primary Provider**: First enabled provider in `config.yml` (order: Gemini, Claude, OpenAI, Perplexity)
2. **Fallback Logic**: If primary fails, tries next enabled provider
3. **Rate Limiting**: Built-in exponential backoff for rate limit errors
4. **Token Tracking**: Monitors token usage across all providers

## Task Processing Pipeline

```mermaid
stateDiagram-v2
    [*] --> Incomplete: Task created in Asana

    Incomplete --> Fetched: Agent polls project
    Fetched --> Classified: Extract intent from title/notes/comments

    Classified --> Routed: Match keywords to workflow
    Routed --> Executing: Workflow executes with LLM

    Executing --> ResultCreated: Create result task
    ResultCreated --> CommentAdded: Add summary to original
    CommentAdded --> Processed: Mark as processed

    Processed --> [*]

    Executing --> Error: LLM failure
    Error --> Retry: Exponential backoff
    Retry --> Executing
    Error --> Failed: Max retries exceeded
    Failed --> [*]
```

## File Structure

```
asana-agent-monitor-oss/
├── config/
│   ├── config.yml                  # User configuration (gitignored)
│   ├── config.example.yml          # Configuration template
│   └── agent_config.rb             # Config loader & validator
├── lib/
│   ├── agent_monitor.rb            # Core agent logic
│   ├── workflow_router.rb          # Routes tasks to workflows
│   ├── processed_tasks_tracker.rb  # Prevents duplicate processing
│   ├── llm/
│   │   ├── base_client.rb          # Factory & base class
│   │   ├── gemini_client.rb        # Google Gemini integration
│   │   ├── claude_client.rb        # Anthropic Claude integration
│   │   ├── openai_client.rb        # OpenAI ChatGPT integration
│   │   └── perplexity_client.rb    # Perplexity AI integration
│   └── workflows/
│       ├── base.rb                 # Base workflow class
│       ├── gemini_code.rb          # Main workflow classifier
│       ├── general_search.rb       # Search & shopping queries
│       ├── article_summary.rb      # Article/content summarization
│       ├── email_draft.rb          # Email drafting
│       ├── newsletter_summary.rb   # Newsletter processing
│       └── open_url.rb             # URL opening
├── bin/
│   └── asana_agent                 # Executable daemon
├── docs/
│   ├── ARCHITECTURE.md             # This file
│   └── QUICKSTART.md               # Setup guide
└── README.md                       # Project overview
```

## Extension Points

### Adding a New Workflow

1. Create `lib/workflows/my_workflow.rb`:
```ruby
module Workflows
  class MyWorkflow < Base
    def execute
      # Your logic here
      create_result_task("Result content")
      add_comment_to_task("Summary")
    end
  end
end
```

2. Add keyword mapping in `config.yml`:
```yaml
workflows:
  keywords:
    my_workflow:
      - keyword1
      - keyword2
```

3. Update `lib/workflows/gemini_code.rb` to route to your workflow

### Adding a New LLM Provider

1. Create `lib/llm/myprovider_client.rb`:
```ruby
module LLM
  class MyProviderClient < ClientBase
    def generate(prompt, options = {})
      # Call your provider's API
      # Return { response: "...", tokens: {...} }
    end
  end
end
```

2. Register in `lib/llm/base_client.rb`:
```ruby
PROVIDERS = {
  'myprovider' => MyProviderClient,
  # ...
}
```

3. Add to `config.example.yml`:
```yaml
ai:
  myprovider:
    enabled: true
    api_key: ${MY_PROVIDER_API_KEY}
```

## Security Considerations

- **API Keys**: Never commit `config.yml` (use environment variables with `${VAR}` syntax)
- **Task Processing**: Each task is processed only once (tracked in `processed_tasks.json`)
- **Comment Monitoring**: Optional - can be disabled to reduce API calls
- **Rate Limiting**: Built-in exponential backoff prevents API abuse
- **Error Handling**: All external API calls wrapped in try/catch with logging

## Performance Optimization

- **Polling Interval**: Configurable (default: 60 seconds)
- **Max Tasks per Cycle**: Limit processing to prevent overload (default: 10)
- **Concurrent Requests**: LLM clients use connection pooling
- **Caching**: Processed tasks cached to avoid redundant API calls
