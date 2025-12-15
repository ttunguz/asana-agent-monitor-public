# Asana Agent Monitor - M1 Mac Setup Guide

## Purpose
Set up your M1 Mac to run the Asana agent monitor 24/7 while your primary laptop sleeps. This ensures continuous task processing without relying on your main machine being awake.

## Architecture Overview

**Current Setup (Primary Laptop)**:
- LaunchAgent daemon with KeepAlive
- Polls Asana every 3 minutes
- Stops when laptop sleeps

**Target Setup (M1 Mac)**:
- Always-on monitoring (screen off, computer awake)
- Same LaunchAgent daemon architecture
- Isolated environment for security

## Setup Options Comparison

### Option 1: M1 Mac Always-On (RECOMMENDED)
**Pros:**
- Physical hardware you control
- No monthly costs
- Better security (local network only)
- Easier debugging & monitoring
- Simple energy consumption (~10W idle)

**Cons:**
- Single point of failure (but can keep primary as backup)
- Requires space for the laptop
- Annual power cost: ~$9/year (10W × 24h × 365d × $0.12/kWh)

### Option 2: Cloud Server (AWS/DigitalOcean/Fly.io)
**Pros:**
- Professional uptime (99.9%+)
- Easy remote access
- Automatic backups
- Scalable if needed

**Cons:**
- Monthly cost: $5-20/month ($60-240/year)
- More complex security setup
- External network access required
- Need to manage SSH keys, firewall rules
- API keys on remote server

**Recommendation**: Start with Option 1 (M1 Mac). It's simpler, cheaper, & more secure for a personal monitoring system.

---

## M1 Mac Setup Instructions

### Phase 1: Prerequisites

#### 1. Install Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 2. Install Ruby (rbenv)
```bash
# Install rbenv
brew install rbenv ruby-build

# Add to ~/.zshrc
echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
source ~/.zshrc

# Install Ruby 3.4.3
rbenv install 3.4.3
rbenv global 3.4.3

# Verify
ruby --version  # Should show 3.4.3
```

#### 3. Install Required Gems
```bash
gem install net-http json logger
```

#### 4. Install Claude Code CLI
```bash
# Follow instructions at https://docs.claude.com/claude-code
# Or use Homebrew if available
brew install claude-code  # If available via Anthropic tap
```

### Phase 2: Copy Project Files

#### 1. Clone/Copy Project
```bash
# Option A: Clone from git (if you have a repo)
git clone <your-repo-url> ~/Documents/coding/asana-agent-monitor

# Option B: Copy from primary laptop
# On primary laptop:
cd ~/Documents/coding/asana-agent-monitor
tar -czf asana-monitor.tar.gz .

# Transfer to M1 (use AirDrop, USB drive, or network)
# On M1:
mkdir -p ~/Documents/coding/asana-agent-monitor
cd ~/Documents/coding/asana-agent-monitor
tar -xzf ~/Downloads/asana-monitor.tar.gz
```

#### 2. Create Required Directories
```bash
cd ~/Documents/coding/asana-agent-monitor
mkdir -p logs config
touch logs/agent.log
touch logs/processed_comments.json
```

### Phase 3: Security Setup

#### 1. Create Secure Environment File
```bash
# Create with restricted permissions (600 = only you can read/write)
touch ~/.asana-monitor-env
chmod 600 ~/.asana-monitor-env

# Edit file (use nano or your preferred editor)
nano ~/.asana-monitor-env
```

Add your API keys (copy from primary laptop's `~/.asana-monitor-env`):
```bash
# Asana Monitor Environment Variables
export ASANA_API_KEY="your_asana_key_here"
export ATTIO_API_KEY="your_attio_key_here"
export OPENAI_API_KEY="your_openai_key_here"
export ANTHROPIC_API_KEY="your_anthropic_key_here"
export HARMONIC_API_KEY="your_harmonic_key_here"
export PERPLEXITY_API_KEY="your_perplexity_key_here"
export GEMINI_API_KEY="your_gemini_key_here"
export ASANA_MONITOR_CLAUDE_FIRST=true
```

#### 2. Create Wrapper Script
```bash
mkdir -p ~/.gemini/bin
nano ~/.gemini/bin/asana_monitor_wrapper.sh
```

Add this content (update Ruby path if needed):
```bash
#!/bin/bash
# Wrapper for launchd execution
# Ensures environment is set up correctly

RUBY_PATH="/Users/YOUR_USERNAME/.rbenv/versions/3.4.3/bin/ruby"
SCRIPT_PATH="/Users/YOUR_USERNAME/Documents/coding/asana-agent-monitor/bin/monitor.rb"

# Source environment variables from secure file (600 permissions)
source /Users/YOUR_USERNAME/.asana-monitor-env

# Log start
echo "[$(date)] Starting monitor via wrapper"

# Execute ruby script
exec "$RUBY_PATH" "$SCRIPT_PATH"
```

Make it executable:
```bash
chmod +x ~/.gemini/bin/asana_monitor_wrapper.sh

# Replace YOUR_USERNAME with your actual username:
whoami  # This shows your username
# Then edit the file to replace YOUR_USERNAME
```

### Phase 4: LaunchAgent Configuration

#### 1. Create LaunchAgent File
```bash
nano ~/Library/LaunchAgents/com.theory.asana-monitor.plist
```

Add this content (update YOUR_USERNAME):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.theory.asana-monitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>/Users/YOUR_USERNAME/.gemini/bin/asana_monitor_wrapper.sh >> /Users/YOUR_USERNAME/Library/Logs/com.theory.asana-monitor.log 2>&amp;1</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
    <key>ProcessType</key>
    <string>Background</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/Users/YOUR_USERNAME/.rbenv/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>/Users/YOUR_USERNAME</string>
        <key>LANG</key>
        <string>en_US.UTF-8</string>
        <key>LC_ALL</key>
        <string>en_US.UTF-8</string>
        <key>LC_CTYPE</key>
        <string>en_US.UTF-8</string>
    </dict>
</dict>
</plist>
```

#### 2. Load LaunchAgent
```bash
# Load the agent
launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist

# Verify it's running
launchctl list | grep asana
# You should see a PID (process ID), not 78

# Check process
ps aux | grep monitor.rb | grep -v grep
# Should show the Ruby process running
```

### Phase 5: Prevent Sleep

#### 1. System Settings
```bash
# Open System Settings
open "x-apple.systempreferences:com.apple.preference.energysaver"
```

Manual steps:
1. System Settings → Battery (or Energy Saver)
2. Set "Turn display off after" to 10 minutes (saves screen)
3. Set "Prevent automatic sleeping when display is off" to ON
4. Disable "Put hard disks to sleep when possible"

#### 2. Alternative: Use caffeinate (Recommended)
Add to LaunchAgent to prevent sleep:
```bash
# Create caffeinate wrapper
nano ~/Library/LaunchAgents/com.theory.prevent-sleep.plist
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.theory.prevent-sleep</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/caffeinate</string>
        <string>-s</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

Load it:
```bash
launchctl load ~/Library/LaunchAgents/com.theory.prevent-sleep.plist
```

---

## Security Safeguards

### 1. File Permissions
```bash
# Verify secure permissions
ls -la ~/.asana-monitor-env
# Should show: -rw------- (600)

# If not, fix it:
chmod 600 ~/.asana-monitor-env
```

### 2. Network Security
```bash
# Enable macOS Firewall
# System Settings → Network → Firewall → Turn On

# Block incoming connections (monitor only makes outbound API calls)
# No need to open any ports
```

### 3. Physical Security
- Keep M1 Mac in a secure location
- Set strong user password
- Enable FileVault encryption:
  ```bash
  # System Settings → Privacy & Security → FileVault
  ```

### 4. API Key Rotation (Recommended)
- Rotate API keys every 90 days
- Use separate API keys for M1 Mac (if providers support it)
- Monitor API usage for anomalies

### 5. SSH Access (Optional but Recommended)
```bash
# Enable SSH for remote access
sudo systemsetup -setremotelogin on

# Add SSH key from primary laptop
ssh-copy-id YOUR_USERNAME@m1-mac-local-ip

# Disable password authentication
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no
sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist
sudo launchctl load /System/Library/LaunchDaemons/ssh.plist
```

### 6. Monitoring & Alerts
```bash
# Set up log rotation
nano ~/Library/LaunchAgents/com.theory.log-rotation.plist
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.theory.log-rotation</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/find</string>
        <string>/Users/YOUR_USERNAME/Documents/coding/asana-agent-monitor/logs</string>
        <string>-name</string>
        <string>*.log</string>
        <string>-mtime</string>
        <string>+30</string>
        <string>-delete</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
```

---

## Testing & Verification

### 1. Manual Test
```bash
# Run monitor manually to test
cd ~/Documents/coding/asana-agent-monitor
~/.rbenv/versions/3.4.3/bin/ruby bin/monitor.rb

# Should see:
# [timestamp] Starting Asana Agent Monitor...
# [timestamp] Monitoring project 1211959613518208
# [timestamp] Polling every 180 seconds
```

Press Ctrl+C to stop, then load LaunchAgent.

### 2. Create Test Task
1. Go to https://app.asana.com/0/1211959613518208
2. Create task: "Test task: What's 2+2?"
3. Wait 3 minutes
4. Check for agent response

### 3. Monitor Logs
```bash
# Real-time log monitoring
tail -f ~/Documents/coding/asana-agent-monitor/logs/agent.log

# Check LaunchAgent log
tail -f ~/Library/Logs/com.theory.asana-monitor.log

# Check for errors
grep ERROR ~/Documents/coding/asana-agent-monitor/logs/agent.log
```

### 4. Verify Continuous Operation
```bash
# Check process uptime
ps aux | grep monitor.rb | grep -v grep

# Check LaunchAgent status
launchctl list | grep asana
```

---

## Maintenance

### Daily Checks (Automated)
```bash
# Create health check script
nano ~/.gemini/bin/monitor_health.sh
```

```bash
#!/bin/bash
# Health check for Asana monitor

MONITOR_RUNNING=$(ps aux | grep monitor.rb | grep -v grep | wc -l)
LAST_LOG=$(tail -1 /Users/YOUR_USERNAME/Documents/coding/asana-agent-monitor/logs/agent.log)

if [ "$MONITOR_RUNNING" -eq 0 ]; then
    echo "❌ Monitor not running! Last log: $LAST_LOG"
    # Optionally: send notification or email
    launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist
else
    echo "✅ Monitor running. Recent activity:"
    tail -3 /Users/YOUR_USERNAME/Documents/coding/asana-agent-monitor/logs/agent.log
fi
```

Schedule daily health check:
```bash
nano ~/Library/LaunchAgents/com.theory.monitor-health.plist
```

### Weekly Tasks
- Review logs for errors
- Check disk space: `df -h`
- Verify API key validity
- Test with a simple task

### Monthly Tasks
- Review security logs
- Update dependencies: `gem update`
- Check for Ruby/Claude updates
- Rotate logs manually if needed

---

## Troubleshooting

### Monitor Not Starting
```bash
# Check LaunchAgent syntax
plutil ~/Library/LaunchAgents/com.theory.asana-monitor.plist

# Check wrapper script permissions
ls -la ~/.gemini/bin/asana_monitor_wrapper.sh
# Should be executable: -rwxr-xr-x

# Check Ruby path
which ruby
~/.rbenv/versions/3.4.3/bin/ruby --version
```

### API Key Errors
```bash
# Verify environment file
cat ~/.asana-monitor-env
# Keys should not have quotes when exported

# Test API access manually
source ~/.asana-monitor-env
curl -H "Authorization: Bearer $ASANA_API_KEY" \
  https://app.asana.com/api/1.0/users/me
```

### Process Dies Unexpectedly
```bash
# Check for OOM (out of memory) kills
log show --predicate 'eventMessage contains "asana"' --last 1h

# Check system resources
top -l 1 | grep -E "(PhysMem|CPU)"

# Increase logging
# Add to bin/monitor.rb (line 1):
$VERBOSE = true
```

### M1 Mac Sleeping Despite Settings
```bash
# Verify caffeinate is running
ps aux | grep caffeinate

# Alternative: use pmset
sudo pmset -a sleep 0
sudo pmset -a disksleep 0
```

---

## Backup Strategy

### 1. Primary Laptop as Backup
Keep LaunchAgent on primary laptop disabled:
```bash
# On primary laptop
launchctl unload ~/Library/LaunchAgents/com.theory.asana-monitor.plist
```

If M1 fails, re-enable:
```bash
launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist
```

### 2. Configuration Backup
```bash
# Backup configuration monthly
cd ~
tar -czf asana-monitor-backup-$(date +%Y%m%d).tar.gz \
  .asana-monitor-env \
  .gemini/bin/asana_monitor_wrapper.sh \
  Library/LaunchAgents/com.theory.asana-monitor.plist \
  Documents/coding/asana-agent-monitor/

# Store backup on external drive or cloud storage
```

---

## Cost Analysis

### M1 Mac Always-On
- **Power consumption**: ~10W idle (M1 efficiency)
- **Annual electricity**: 10W × 24h × 365d = 87.6 kWh
- **Cost**: 87.6 kWh × $0.12/kWh = **$10.51/year**

### Cloud Server Alternative
- **DigitalOcean Droplet**: $6/month = **$72/year**
- **AWS Lightsail**: $5/month = **$60/year**
- **Fly.io**: $2-5/month = **$24-60/year** (hobby tier)

**Savings with M1**: $50-60/year + full control

---

## Security Checklist

- [ ] FileVault enabled
- [ ] Firewall enabled
- [ ] ~/.asana-monitor-env has 600 permissions
- [ ] Strong user password set
- [ ] SSH key-only authentication (if enabled)
- [ ] API keys stored securely (not in code/git)
- [ ] Log rotation configured
- [ ] Physical location secured
- [ ] Automatic updates enabled
- [ ] Regular backup schedule set

---

## Next Steps

1. **Complete setup** following phases above
2. **Test thoroughly** with sample tasks
3. **Monitor for 1 week** to ensure stability
4. **Disable primary laptop** monitor once confident
5. **Set calendar reminder** for monthly maintenance
6. **Document any issues** & solutions for future reference

---

## Questions & Support

If issues arise:
1. Check logs: `~/Documents/coding/asana-agent-monitor/logs/agent.log`
2. Verify process: `ps aux | grep monitor.rb`
3. Test manually: Run `bin/monitor.rb` directly
4. Review this guide's Troubleshooting section

For updates, see:
- `README.md` - System architecture
- `QUICK_START.md` - Feature documentation
- `CHANGELOG_*.md` - Recent changes
