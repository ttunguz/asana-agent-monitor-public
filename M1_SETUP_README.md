# Asana Agent Monitor - Automated M1 Setup

## Quick Start

Transfer this repository to your M1 Mac, then run:

```bash
cd ~/Documents/coding/asana-agent-monitor
./setup_m1.sh
```

That's it! The script will handle everything automatically.

## What the Setup Script Does

### ✅ Automated Steps (No User Input Needed)

1. **Dependencies Installation**
   - Installs Homebrew (if not present)
   - Installs rbenv & Ruby 3.4.3
   - Installs required gems (net-http, json, logger)

2. **Project Configuration**
   - Creates project directories
   - Sets up log files
   - Creates wrapper scripts with correct paths

3. **LaunchAgent Setup**
   - Creates & validates LaunchAgent plist
   - Sets up sleep prevention daemon
   - Loads & starts services

4. **Health Monitoring**
   - Creates health check script
   - Sets up automatic restart on failure

### ⚙️ Interactive Steps (Requires Your Input)

1. **API Keys** - You'll be prompted to enter:
   - Asana API Key
   - Attio API Key
   - OpenAI API Key
   - Anthropic API Key
   - Harmonic API Key
   - Perplexity API Key
   - Gemini API Key

2. **Security Settings** - Optional prompts to open:
   - FileVault settings (disk encryption)
   - Firewall settings
   - Energy Saver settings

3. **Manual Testing** - Brief test run to verify everything works

## Transfer Methods

### Method 1 : AirDrop (Easiest)
On primary laptop:
```bash
cd ~/Documents/coding/asana-agent-monitor
tar -czf asana-monitor.tar.gz .
# AirDrop the .tar.gz file to M1 Mac
```

On M1 Mac:
```bash
mkdir -p ~/Documents/coding/asana-agent-monitor
cd ~/Documents/coding/asana-agent-monitor
tar -xzf ~/Downloads/asana-monitor.tar.gz
./setup_m1.sh
```

### Method 2 : Git (If You Have a Repo)
On M1 Mac:
```bash
git clone <your-repo-url> ~/Documents/coding/asana-agent-monitor
cd ~/Documents/coding/asana-agent-monitor
./setup_m1.sh
```

### Method 3 : Network Transfer
On primary laptop:
```bash
cd ~/Documents/coding
python3 -m http.server 8000
# Note the IP address shown
```

On M1 Mac:
```bash
cd ~/Documents/coding
curl -O http://<primary-laptop-ip>:8000/asana-agent-monitor.tar.gz
tar -xzf asana-agent-monitor.tar.gz
cd asana-agent-monitor
./setup_m1.sh
```

## Script Options

### Skip Homebrew Installation
If Homebrew is already installed:
```bash
./setup_m1.sh --skip-homebrew
```

### Skip Ruby Installation
If Ruby 3.4.3 is already configured:
```bash
./setup_m1.sh --skip-ruby
```

### Specify Source Path
If project files are in a different location:
```bash
./setup_m1.sh --source-path /path/to/source/files
```

### Combined Options
```bash
./setup_m1.sh --skip-homebrew --skip-ruby --source-path /tmp/asana-monitor
```

## Troubleshooting

### Setup Fails at Ruby Installation
If Ruby installation times out or fails:
```bash
# Install Ruby manually first
brew install rbenv ruby-build
rbenv install 3.4.3
rbenv global 3.4.3

# Then run setup with --skip-ruby
./setup_m1.sh --skip-ruby
```

### Permission Errors
If you get permission errors:
```bash
# Ensure script is executable
chmod +x setup_m1.sh

# Check file permissions
ls -la setup_m1.sh
# Should show: -rwxr-xr-x
```

### LaunchAgent Won't Load
If LaunchAgent fails to load:
```bash
# Check plist syntax
plutil ~/Library/LaunchAgents/com.theory.asana-monitor.plist

# View LaunchAgent logs
tail -20 ~/Library/Logs/com.theory.asana-monitor.log

# Manually test wrapper
~/.gemini/bin/asana_monitor_wrapper.sh
```

### Monitor Process Dies Immediately
If process starts but dies right away:
```bash
# Test manually to see error
~/.rbenv/versions/3.4.3/bin/ruby ~/Documents/coding/asana-agent-monitor/bin/monitor.rb

# Check environment file
cat ~/.asana-monitor-env
# Verify all API keys are set

# Check logs
tail -50 ~/Documents/coding/asana-agent-monitor/logs/agent.log
```

## Post-Setup Verification

### 1. Check LaunchAgent Status
```bash
launchctl list | grep asana
# Should show a PID (not 78)
```

### 2. Check Process
```bash
ps aux | grep monitor.rb | grep -v grep
# Should show ruby process running
```

### 3. Check Sleep Prevention
```bash
ps aux | grep caffeinate | grep -v grep
# Should show caffeinate running
```

### 4. Run Health Check
```bash
~/.gemini/bin/monitor_health.sh
# Should show ✅ Monitor running
```

### 5. Test with Real Task
1. Go to https://app.asana.com/0/1211959613518208
2. Create task: "Test task: What is the capital of France?"
3. Wait 3 minutes (polling interval)
4. Check task for agent response

## Security Checklist

After setup completes, verify:

- [ ] FileVault disk encryption enabled
- [ ] Firewall enabled & configured
- [ ] `~/.asana-monitor-env` has 600 permissions
- [ ] API keys not exposed in code/logs
- [ ] Strong user password set
- [ ] Physical location secured
- [ ] Energy Saver configured (prevent sleep)
- [ ] Automatic updates enabled

## Useful Commands

### Status & Monitoring
```bash
# Health check
~/.gemini/bin/monitor_health.sh

# View real-time logs
tail -f ~/Documents/coding/asana-agent-monitor/logs/agent.log

# LaunchAgent logs
tail -f ~/Library/Logs/com.theory.asana-monitor.log

# Process status
ps aux | grep monitor.rb
```

### Start/Stop
```bash
# Stop monitor
launchctl unload ~/Library/LaunchAgents/com.theory.asana-monitor.plist

# Start monitor
launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist

# Restart monitor
launchctl unload ~/Library/LaunchAgents/com.theory.asana-monitor.plist
launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist
```

### Manual Testing
```bash
# Run monitor manually (for debugging)
~/.rbenv/versions/3.4.3/bin/ruby ~/Documents/coding/asana-agent-monitor/bin/monitor.rb

# Test with environment
source ~/.asana-monitor-env
ruby ~/Documents/coding/asana-agent-monitor/bin/monitor.rb
```

## Maintenance Schedule

### Daily (Automated)
- Monitor keeps running via KeepAlive
- Logs rotate automatically

### Weekly (5 minutes)
```bash
# Check health
~/.gemini/bin/monitor_health.sh

# Review recent logs
tail -50 ~/Documents/coding/asana-agent-monitor/logs/agent.log | grep ERROR
```

### Monthly (15 minutes)
```bash
# Update dependencies
gem update

# Check disk space
df -h

# Review security logs
log show --predicate 'eventMessage contains "asana"' --last 7d | grep -i error
```

### Quarterly (30 minutes)
- Rotate API keys
- Update Ruby version (if needed)
- Test failover to primary laptop
- Review & optimize

## Cost Analysis

### M1 Mac Always-On
- Power consumption: ~10W idle
- Annual electricity: 87.6 kWh
- Cost: $10.51/year @ $0.12/kWh

### Benefits
- ✅ One-time setup (15-30 minutes)
- ✅ Minimal maintenance (~1 hour/month)
- ✅ Full control & security
- ✅ Easy debugging
- ✅ No recurring cloud costs

## Next Steps After Setup

1. **Monitor for 24 hours** - Ensure stability
2. **Disable primary laptop monitor** - Once confident
3. **Set calendar reminders**:
   - Weekly: Health check (5 min)
   - Monthly: Maintenance (15 min)
   - Quarterly: API key rotation (30 min)
4. **Document customizations** - If you make changes

## Getting Help

If you encounter issues:

1. **Check logs first**:
   ```bash
   tail -100 ~/Documents/coding/asana-agent-monitor/logs/agent.log
   tail -100 ~/Library/Logs/com.theory.asana-monitor.log
   ```

2. **Review setup guide**: `M1_SETUP_GUIDE.md`

3. **Check security guide**: `SECURITY_HARDENING.md`

4. **Test manually**:
   ```bash
   source ~/.asana-monitor-env
   ruby ~/Documents/coding/asana-agent-monitor/bin/monitor.rb
   ```

5. **Verify dependencies**:
   ```bash
   ruby --version  # Should be 3.4.3
   which ruby      # Should point to rbenv
   gem list        # Should include net-http, json, logger
   ```

## Backup & Recovery

### Backup Configuration
```bash
cd ~
tar -czf asana-monitor-backup-$(date +%Y%m%d).tar.gz \
  .asana-monitor-env \
  .gemini/bin/asana_monitor_wrapper.sh \
  Library/LaunchAgents/com.theory.asana-monitor.plist \
  Library/LaunchAgents/com.theory.prevent-sleep.plist \
  Documents/coding/asana-agent-monitor/
```

### Restore from Backup
```bash
cd ~
tar -xzf asana-monitor-backup-YYYYMMDD.tar.gz

# Reload LaunchAgents
launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist
launchctl load ~/Library/LaunchAgents/com.theory.prevent-sleep.plist
```

## Uninstall (If Needed)

To completely remove the setup:

```bash
# Stop LaunchAgents
launchctl unload ~/Library/LaunchAgents/com.theory.asana-monitor.plist
launchctl unload ~/Library/LaunchAgents/com.theory.prevent-sleep.plist

# Remove LaunchAgent files
rm ~/Library/LaunchAgents/com.theory.asana-monitor.plist
rm ~/Library/LaunchAgents/com.theory.prevent-sleep.plist

# Remove project
rm -rf ~/Documents/coding/asana-agent-monitor

# Remove wrapper scripts
rm -rf ~/.gemini/bin/asana_monitor_wrapper.sh
rm -rf ~/.gemini/bin/monitor_health.sh

# Remove environment file (contains API keys!)
rm ~/.asana-monitor-env

# Optional: Remove Ruby (if only used for this)
rbenv uninstall 3.4.3
```

---

## Summary

This automated setup script makes it trivial to configure your M1 Mac for 24/7 Asana monitoring. The entire process takes 15-30 minutes & requires minimal technical knowledge.

**Key Features**:
- ✅ Fully automated dependency installation
- ✅ Secure API key management (600 permissions)
- ✅ LaunchAgent daemon with KeepAlive
- ✅ Sleep prevention
- ✅ Health monitoring & auto-restart
- ✅ Comprehensive error checking
- ✅ Clear status output & verification

**Time Investment**:
- Setup: 15-30 minutes (one-time)
- Weekly: 5 minutes (health check)
- Monthly: 15 minutes (maintenance)
- Quarterly: 30 minutes (API rotation)

**Cost**: ~$10/year in electricity

For detailed documentation, see:
- `M1_SETUP_GUIDE.md` - Complete manual setup guide
- `SECURITY_HARDENING.md` - Security best practices
- `DEPLOYMENT_OPTIONS.md` - Alternative deployment options
