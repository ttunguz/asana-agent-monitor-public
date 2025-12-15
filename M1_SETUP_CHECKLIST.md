# M1 Mac Setup Checklist - Quick Reference

Print this checklist & check off items as you complete them.

---

## Before You Start

- [ ] M1 Mac is powered on & connected to network
- [ ] You have admin password for M1 Mac
- [ ] You have all API keys ready (see list below)
- [ ] Project files transferred to M1 Mac

### Required API Keys
- [ ] Asana API Key
- [ ] Attio API Key
- [ ] OpenAI API Key
- [ ] Anthropic API Key
- [ ] Harmonic API Key
- [ ] Perplexity API Key
- [ ] Gemini API Key

---

## Setup Process (15-30 minutes)

### 1. Transfer Files (5 minutes)
- [ ] Files copied to `~/Documents/coding/asana-agent-monitor`
- [ ] Verified `bin/monitor.rb` exists
- [ ] Verified `lib/` directory exists

### 2. Run Setup Script (10-20 minutes)
```bash
cd ~/Documents/coding/asana-agent-monitor
./setup_m1.sh
```

- [ ] Script started successfully
- [ ] Homebrew installed/verified
- [ ] Ruby 3.4.3 installed/verified
- [ ] Gems installed
- [ ] API keys entered
- [ ] Environment file created (600 permissions)
- [ ] Wrapper scripts created
- [ ] LaunchAgent loaded
- [ ] Process verified running

### 3. Manual Configuration (5 minutes)
- [ ] FileVault enabled (System Settings → Privacy & Security)
- [ ] Firewall enabled (System Settings → Network → Firewall)
- [ ] Energy Saver configured:
  - [ ] Display off after 10 minutes
  - [ ] Prevent sleep when display off: ON
  - [ ] Put hard disks to sleep: OFF

### 4. Testing (5 minutes)
- [ ] Health check passed: `~/.gemini/bin/monitor_health.sh`
- [ ] Logs showing activity: `tail -f ~/Documents/coding/asana-agent-monitor/logs/agent.log`
- [ ] Created test Asana task
- [ ] Agent responded to test task (wait 3 minutes)

---

## Verification Commands

### Status Check
```bash
# Should show PID (not 78)
launchctl list | grep asana

# Should show ruby process
ps aux | grep monitor.rb | grep -v grep

# Should show caffeinate running
ps aux | grep caffeinate | grep -v grep

# Health check
~/.gemini/bin/monitor_health.sh
```

- [ ] LaunchAgent showing PID
- [ ] Monitor process running
- [ ] Caffeinate active
- [ ] Health check returns ✅

---

## Security Verification

```bash
# Check environment file permissions (should be 600)
ls -la ~/.asana-monitor-env

# Verify FileVault
fdesetup status

# Verify Firewall
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

- [ ] Environment file: `-rw------- (600)`
- [ ] FileVault: "FileVault is On"
- [ ] Firewall: "enabled"

---

## Post-Setup Checklist

### Immediate (Day 1)
- [ ] Test task created & answered
- [ ] Logs reviewed for errors
- [ ] Screen configured to turn off
- [ ] M1 Mac in secure location

### 24 Hours Later
- [ ] Process still running
- [ ] No errors in logs
- [ ] Health check passes
- [ ] System stayed awake overnight

### 1 Week Later
- [ ] Disable monitor on primary laptop
- [ ] Verify M1 Mac handling all tasks
- [ ] Review weekly logs
- [ ] Set maintenance reminders

---

## Maintenance Reminders

### Set Calendar Reminders For:
- [ ] **Weekly** (every Monday): Health check (5 min)
- [ ] **Monthly** (1st of month): Dependency updates (15 min)
- [ ] **Quarterly** (Jan/Apr/Jul/Oct 1st): API key rotation (30 min)

---

## Useful Commands Reference

### Health & Status
```bash
~/.gemini/bin/monitor_health.sh           # Health check
tail -f ~/Documents/coding/asana-agent-monitor/logs/agent.log  # Real-time logs
launchctl list | grep asana              # LaunchAgent status
ps aux | grep monitor.rb                 # Process check
```

### Start/Stop
```bash
# Stop
launchctl unload ~/Library/LaunchAgents/com.theory.asana-monitor.plist

# Start
launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist
```

### Manual Test
```bash
source ~/.asana-monitor-env
ruby ~/Documents/coding/asana-agent-monitor/bin/monitor.rb
```

---

## Troubleshooting Quick Reference

### Problem: Process won't start
**Solution**: Check wrapper script permissions & Ruby path
```bash
ls -la ~/.gemini/bin/asana_monitor_wrapper.sh
which ruby
~/.rbenv/versions/3.4.3/bin/ruby --version
```

### Problem: API key errors
**Solution**: Verify environment file
```bash
cat ~/.asana-monitor-env
source ~/.asana-monitor-env
echo $ASANA_API_KEY  # Should show your key
```

### Problem: M1 Mac keeps sleeping
**Solution**: Check caffeinate & energy settings
```bash
ps aux | grep caffeinate
# Also: System Settings → Battery → Prevent sleep
```

### Problem: LaunchAgent exits with code 78
**Solution**: Check plist syntax & reload
```bash
plutil ~/Library/LaunchAgents/com.theory.asana-monitor.plist
launchctl unload ~/Library/LaunchAgents/com.theory.asana-monitor.plist
launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist
```

---

## Backup Checklist

### Monthly Backup
- [ ] Run backup command:
```bash
cd ~
tar -czf asana-monitor-backup-$(date +%Y%m%d).tar.gz \
  .asana-monitor-env \
  .gemini/bin/asana_monitor_wrapper.sh \
  Library/LaunchAgents/com.theory.asana-monitor.plist \
  Documents/coding/asana-agent-monitor/
```
- [ ] Copy backup to external drive or cloud storage
- [ ] Test restore on test machine (quarterly)

---

## Emergency Procedures

### If M1 Mac Fails
1. **Immediate**: Re-enable monitor on primary laptop
   ```bash
   launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist
   ```

2. **Within 1 hour**: Investigate M1 Mac issue
   - Check logs
   - Run health check
   - Restart LaunchAgent

3. **Within 24 hours**: Fix or fail over to cloud server

### If API Keys Compromised
1. **Immediately**: Disable compromised keys in API provider dashboards
2. **Within 1 hour**: Generate new keys
3. **Update**: Edit `~/.asana-monitor-env` with new keys
4. **Restart**: Reload LaunchAgent
5. **Verify**: Test with sample task

---

## Success Criteria

Your setup is complete & successful when:

✅ LaunchAgent shows running PID
✅ Monitor process visible in `ps aux`
✅ Health check returns green status
✅ Test task receives agent response
✅ System stays awake overnight
✅ FileVault & Firewall enabled
✅ Environment file has 600 permissions
✅ No errors in logs for 24 hours
✅ Maintenance reminders set

---

## Setup Complete!

Date completed: ________________

Setup time: _______ minutes

Notes:
_______________________________________________
_______________________________________________
_______________________________________________
_______________________________________________

**Next Review Date**: ________________ (1 week from setup)

**Quarterly Maintenance Date**: ________________ (3 months from setup)

---

## Support Resources

- **Full Guide**: `M1_SETUP_GUIDE.md`
- **Security Guide**: `SECURITY_HARDENING.md`
- **Quick Setup**: `M1_SETUP_README.md`
- **Logs**: `~/Documents/coding/asana-agent-monitor/logs/agent.log`
- **LaunchAgent Log**: `~/Library/Logs/com.theory.asana-monitor.log`

---

**Estimated Cost**: $10/year (electricity)
**Estimated Time**: 15-30 min setup, ~1 hour/month maintenance
**Uptime Target**: 99%+ (with LaunchAgent KeepAlive)
