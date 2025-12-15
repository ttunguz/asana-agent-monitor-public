# Asana Agent Monitor - M1 Mac Setup Checklist

## Quick Start (60 Minutes)

### Prerequisites (15 min)
- [ ] Homebrew installed : `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- [ ] Ruby 3.4.3 via rbenv : `brew install rbenv && rbenv install 3.4.3 && rbenv global 3.4.3`
- [ ] Required gems : `gem install net-http json logger`
- [ ] Claude Code CLI installed : Follow https://docs.claude.com/claude-code

### Project Setup (10 min)
- [ ] Copy project to M1 Mac : `~/Documents/coding/asana-agent-monitor/`
- [ ] Create logs directory : `mkdir -p logs && touch logs/agent.log logs/processed_comments.json`
- [ ] Verify Ruby path : `which ruby` (should show rbenv version)

### Security Configuration (15 min)
- [ ] Create environment file : `touch ~/.asana-monitor-env && chmod 600 ~/.asana-monitor-env`
- [ ] Add API keys to `~/.asana-monitor-env` (copy from primary laptop)
- [ ] Verify permissions : `ls -la ~/.asana-monitor-env` (should show `-rw-------`)
- [ ] Enable FileVault : System Settings → Privacy & Security → FileVault
- [ ] Enable Firewall : System Settings → Network → Firewall → Turn On

### LaunchAgent Setup (10 min)
- [ ] Create wrapper script : `mkdir -p ~/.gemini/bin && nano ~/.gemini/bin/asana_monitor_wrapper.sh`
- [ ] Make executable : `chmod +x ~/.gemini/bin/asana_monitor_wrapper.sh`
- [ ] Create LaunchAgent plist : `nano ~/Library/LaunchAgents/com.theory.asana-monitor.plist`
- [ ] Update YOUR_USERNAME in both files : `whoami` to find username
- [ ] Load LaunchAgent : `launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist`

### Prevent Sleep (5 min)
- [ ] Create prevent-sleep plist : `nano ~/Library/LaunchAgents/com.theory.prevent-sleep.plist`
- [ ] Load prevent-sleep : `launchctl load ~/Library/LaunchAgents/com.theory.prevent-sleep.plist`
- [ ] Verify settings : System Settings → Lock Screen → Never for sleep

### Testing (5 min)
- [ ] Check process running : `ps aux | grep monitor.rb | grep -v grep`
- [ ] Check LaunchAgent status : `launchctl list | grep asana` (should show PID, not 78)
- [ ] Create test task in Asana : https://app.asana.com/0/1211959613518208
- [ ] Wait 3 minutes & verify response
- [ ] Check logs : `tail -f ~/Documents/coding/asana-agent-monitor/logs/agent.log`

---

## Security Hardening Checklist (30 min)

### Essential Security
- [ ] FileVault disk encryption enabled
- [ ] Firewall enabled & blocking all incoming
- [ ] API keys file has 600 permissions
- [ ] Strong user password set
- [ ] Physical location secured (locked drawer/room)

### Recommended Security
- [ ] Firmware password set : `sudo firmwarepasswd -setpasswd`
- [ ] SSH disabled or key-only : System Settings → Sharing → Remote Login
- [ ] Log scrubbing script created : `~/.gemini/bin/scrub_logs.sh`
- [ ] Security monitoring script : `~/.gemini/bin/security_monitor.sh`
- [ ] Backup script configured : `~/.gemini/bin/secure_backup.sh`

### Optional Security
- [ ] Separate API keys for M1 Mac (if provider supports)
- [ ] Network monitoring tool installed (Little Snitch, etc.)
- [ ] Automatic security updates enabled
- [ ] Calendar reminders for key rotation (every 90 days)

---

## Maintenance Schedule

### Daily (Automated)
- [ ] Monitor runs automatically every 3 minutes
- [ ] Logs written to `~/Documents/coding/asana-agent-monitor/logs/agent.log`
- [ ] Processed comments tracked in `logs/processed_comments.json`

### Weekly (5 min)
- [ ] Review logs for errors : `grep ERROR logs/agent.log`
- [ ] Verify process running : `ps aux | grep monitor.rb`
- [ ] Check disk space : `df -h`
- [ ] Test with sample Asana task

### Monthly (15 min)
- [ ] Update Ruby gems : `gem update`
- [ ] Check for system updates : Software Update
- [ ] Review security logs : `cat logs/security.log`
- [ ] Test backup restore process
- [ ] Verify API keys are valid

### Quarterly (30 min)
- [ ] Rotate all API keys
- [ ] Review security hardening checklist
- [ ] Update documentation if changes made
- [ ] Test incident response plan (tabletop)

---

## Troubleshooting Quick Reference

### Monitor Not Running
```bash
# Check status
launchctl list | grep asana
ps aux | grep monitor.rb

# Restart
launchctl unload ~/Library/LaunchAgents/com.theory.asana-monitor.plist
launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist
```

### API Key Errors
```bash
# Verify environment file
cat ~/.asana-monitor-env

# Test API access
source ~/.asana-monitor-env
curl -H "Authorization: Bearer $ASANA_API_KEY" https://app.asana.com/api/1.0/users/me
```

### Mac Sleeping Despite Settings
```bash
# Check caffeinate
ps aux | grep caffeinate

# Alternative: use pmset
sudo pmset -a sleep 0
sudo pmset -a disksleep 0
```

### Process Dies Unexpectedly
```bash
# Check logs
tail -50 ~/Library/Logs/com.theory.asana-monitor.log

# Check for crashes
log show --predicate 'eventMessage contains "asana"' --last 1h

# Manual run for debugging
cd ~/Documents/coding/asana-agent-monitor
~/.rbenv/versions/3.4.3/bin/ruby bin/monitor.rb
```

---

## Quick Commands Reference

### Status Checks
```bash
# Monitor status
ps aux | grep monitor.rb | grep -v grep

# LaunchAgent status
launchctl list | grep asana

# Logs (real-time)
tail -f ~/Documents/coding/asana-agent-monitor/logs/agent.log

# Logs (recent errors)
grep ERROR ~/Documents/coding/asana-agent-monitor/logs/agent.log | tail -20
```

### Control Commands
```bash
# Stop monitor
launchctl unload ~/Library/LaunchAgents/com.theory.asana-monitor.plist

# Start monitor
launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist

# Restart monitor
launchctl unload ~/Library/LaunchAgents/com.theory.asana-monitor.plist && \
launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist
```

### Debugging
```bash
# Run manually (see output)
cd ~/Documents/coding/asana-agent-monitor
~/.rbenv/versions/3.4.3/bin/ruby bin/monitor.rb

# Check Ruby version
ruby --version  # Should show 3.4.3

# Check Claude Code CLI
claude --version  # Verify installed

# Test API keys
source ~/.asana-monitor-env
echo $ASANA_API_KEY  # Should show key (don't share output!)
```

---

## File Locations Reference

### Configuration Files
- Environment vars : `~/.asana-monitor-env` (600 permissions)
- Wrapper script : `~/.gemini/bin/asana_monitor_wrapper.sh`
- LaunchAgent plist : `~/Library/LaunchAgents/com.theory.asana-monitor.plist`
- Project directory : `~/Documents/coding/asana-agent-monitor/`

### Log Files
- Agent logs : `~/Documents/coding/asana-agent-monitor/logs/agent.log`
- Processed comments : `~/Documents/coding/asana-agent-monitor/logs/processed_comments.json`
- LaunchAgent logs : `~/Library/Logs/com.theory.asana-monitor.log`
- Security logs : `~/Documents/coding/asana-agent-monitor/logs/security.log`

### Documentation
- Main README : `~/Documents/coding/asana-agent-monitor/README.md`
- M1 Setup Guide : `~/Documents/coding/asana-agent-monitor/M1_SETUP_GUIDE.md`
- Security Hardening : `~/Documents/coding/asana-agent-monitor/SECURITY_HARDENING.md`
- Deployment Options : `~/Documents/coding/asana-agent-monitor/DEPLOYMENT_OPTIONS.md`
- This Checklist : `~/Documents/coding/asana-agent-monitor/SETUP_CHECKLIST.md`

---

## Support & Resources

### Documentation
- Full setup guide : `M1_SETUP_GUIDE.md`
- Security best practices : `SECURITY_HARDENING.md`
- Deployment comparison : `DEPLOYMENT_OPTIONS.md`
- System architecture : `README.md`
- Feature guide : `QUICK_START.md`

### Key Links
- Asana Project : https://app.asana.com/0/1211959613518208
- Claude Code Docs : https://docs.claude.com/claude-code
- macOS Security Guide : https://github.com/drduh/macOS-Security-and-Privacy-Guide

### Emergency Contacts
- Primary laptop (backup) : Keep LaunchAgent ready to re-enable
- Cloud server (optional) : Set up as failover if needed

---

## Success Criteria

You'll know setup is complete & successful when:
- [ ] Monitor runs continuously (check `ps aux | grep monitor.rb`)
- [ ] LaunchAgent shows PID (not 78) : `launchctl list | grep asana`
- [ ] Test task gets response within 3 minutes
- [ ] Logs show regular polling activity
- [ ] M1 Mac doesn't sleep (screen off is OK)
- [ ] No errors in logs after 24 hours
- [ ] Security checklist items completed
- [ ] You can restart Mac & monitor auto-starts

**Total Setup Time** : ~1.5 hours
**Ongoing Maintenance** : ~5 min/week

---

## Next Steps After Setup

1. **Disable primary laptop monitor** (once confident M1 is stable)
   ```bash
   # On primary laptop
   launchctl unload ~/Library/LaunchAgents/com.theory.asana-monitor.plist
   ```

2. **Set calendar reminders**
   - Weekly : Check logs (5 min)
   - Monthly : Update gems & verify API keys (15 min)
   - Quarterly : Rotate API keys (30 min)

3. **Create backup plan**
   - Configure backup script : `~/.gemini/bin/secure_backup.sh`
   - Store backups on external drive or cloud (encrypted)
   - Test restore process within first month

4. **Monitor & optimize**
   - Track uptime & reliability over first month
   - Adjust polling interval if needed (in `config/agent_config.rb`)
   - Fine-tune security settings based on experience

5. **Document any changes**
   - Keep notes on customizations made
   - Update this checklist if process changes
   - Share improvements with team/community

---

**Ready to start?** Follow M1_SETUP_GUIDE.md for detailed step-by-step instructions!
