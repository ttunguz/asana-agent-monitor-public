# Asana Agent Monitor

AI-powered Asana task automation with natural language processing.

## Features
- 🤖 AI-powered task processing with Gemini, Claude, OpenAI, or Perplexity
- 🔍 General web research (shopping, product recommendations, Q&A)
- 📧 Email drafting with context awareness
- 📰 Newsletter summarization (requires email provider)
- 🗣️ Comment monitoring & conversation tracking

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
   # Edit config.yml with your Asana and AI keys
   ```

4. **Run**:
   ```bash
   ruby bin/monitor.rb
   ```

## Configuration

See `config/config.example.yml` for detailed configuration options.

### Asana Setup
1. Create a project in Asana for agent tasks
2. Get project GID from URL: `https://app.asana.com/0/PROJECT_GID`
3. Add to `config.yml`

### AI Provider
Choose one:
- **Gemini**: Set `gemini_api_key`
- **Claude**: Set `claude_api_key`
- **OpenAI**: Set `openai_api_key`
- **Perplexity**: Set `perplexity_api_key`

## Usage

1. Create a task in your monitored Asana project
2. Add task notes with your request (e.g., "Search for the best Lego sets under $50")
3. Agent processes task automatically (every 3 minutes by default)
4. Agent adds results as a comment

## License

MIT License - see LICENSE file.