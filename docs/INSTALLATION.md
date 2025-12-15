# Installation Guide

## 1. System Requirements

- Ruby 3.0 or higher
- Bundler (`gem install bundler`)
- Asana account
- An AI provider API key (Google Gemini, Anthropic Claude, OpenAI, or Perplexity)

## 2. Setup

### Clone Repository
```bash
git clone https://github.com/yourusername/asana-agent-monitor.git
cd asana-agent-monitor
```

### Install Dependencies
```bash
bundle install
```

### Configuration

Copy the example configuration:
```bash
cp config/config.example.yml config/config.yml
```

Edit `config/config.yml` with your settings.

## 3. Asana Configuration

1. **Get Personal Access Token**:
   - Go to Asana > My Profile Settings > Apps > Manage Developer Apps
   - Click "Create New Personal Access Token"
   - Copy the token

2. **Get Project GID**:
   - Open your project in Asana
   - The URL will look like: `https://app.asana.com/0/1234567890/list`
   - The number `1234567890` is your Project GID
   - Add this to `config.yml` under `project_gids`

3. **Get Workspace GID**:
   - You can find this via API or often in the URL for home/portfolio views
   - Or use the API explorer: `https://developers.asana.com/explorer`

## 4. Running the Agent

### Manual Run
```bash
ruby bin/monitor.rb
```

### Run as Service (macOS)
1. Edit `examples/launchd.plist` (update paths)
2. Copy to `~/Library/LaunchAgents/`
3. Load with `launchctl load ~/Library/LaunchAgents/com.asana.agent.plist`

## 5. Troubleshooting

check `logs/agent.log` for errors.
