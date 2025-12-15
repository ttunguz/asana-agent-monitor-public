# Security Hardening Guide for Asana Agent Monitor

## Overview
This guide covers security best practices for running the Asana agent monitor on an always-on M1 Mac.

## Threat Model

### What We're Protecting
1. **API Keys** : Asana, Attio, OpenAI, Anthropic, Harmonic, Perplexity, Gemini
2. **Task Data** : Company research, emails, sensitive business information
3. **System Access** : Preventing unauthorized use of the M1 Mac

### Potential Threats
1. Physical access by unauthorized person
2. Network-based attacks (remote exploitation)
3. Malware/ransomware
4. API key leakage through logs or backups
5. Insider threats (accidental or malicious)

### Risk Level Assessment
- **Low-Medium** : Personal/small team use, local network only
- **Critical Assets** : API keys, task data containing PII or business secrets

---

## Defense Layers

### Layer 1 : Physical Security

#### Best Practices
- [ ] Keep M1 Mac in a locked room or desk drawer
- [ ] Use Kensington lock if in shared space
- [ ] Set auto-lock timeout (5-10 minutes)
- [ ] Require password immediately on wake/screensaver
- [ ] Disable Touch ID if shared space
- [ ] Use firmware password (prevents booting from external drives)

#### Configuration
```bash
# Set firmware password (requires restart)
sudo firmwarepasswd -setpasswd

# Verify firmware password is set
sudo firmwarepasswd -check
# Should show: Password Enabled: Yes

# Set auto-lock timeout
# System Settings → Lock Screen → Require password immediately after sleep
```

#### Physical Access Scenarios
- **Scenario** : Laptop stolen or accessed by unauthorized person
- **Mitigation** : FileVault encryption + strong password = data unreadable
- **Residual Risk** : Low (requires both physical access & password cracking)

---

### Layer 2 : Disk Encryption

#### FileVault Configuration
```bash
# Enable FileVault
sudo fdesetup enable

# Verify FileVault status
fdesetup status
# Should show: FileVault is On

# Store recovery key securely (NOT on the Mac)
# Print recovery key & store in safe deposit box or secure password manager
```

#### Best Practices
- [ ] Enable FileVault before storing any API keys
- [ ] Back up recovery key to secure location (password manager or physical safe)
- [ ] Test recovery key works (write it down, verify you can read it)
- [ ] Never store recovery key in iCloud or email

#### Encryption Scenarios
- **Scenario** : Disk removed & accessed from another computer
- **Mitigation** : FileVault encrypts entire disk with AES-XTS-128
- **Residual Risk** : Very low (military-grade encryption)

---

### Layer 3 : Network Security

#### Firewall Configuration
```bash
# Enable macOS Firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Block all incoming connections
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on

# Allow only essential services (if needed)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/bin/ruby
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /usr/bin/ruby

# Verify firewall status
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

#### SSH Hardening (if enabled)
```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config

# Add/modify these lines:
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM no
AllowUsers YOUR_USERNAME
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2

# Restart SSH
sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist
sudo launchctl load /System/Library/LaunchDaemons/ssh.plist
```

#### Network Monitoring
```bash
# Monitor incoming connections
sudo lsof -i -P | grep LISTEN

# Check for unexpected network activity
nettop -P -J bytes_in,bytes_out

# Review firewall logs
log show --predicate 'process == "socketfilterfw"' --last 1h
```

#### Best Practices
- [ ] Disable SSH if not needed for remote access
- [ ] Use SSH keys only (no password authentication)
- [ ] Enable firewall to block all incoming connections
- [ ] Monitor network activity weekly
- [ ] Keep M1 Mac on private network (not public WiFi)
- [ ] Use VPN if accessing from untrusted networks

#### Network Attack Scenarios
- **Scenario** : Attacker on same network attempts to exploit services
- **Mitigation** : Firewall blocks all incoming, monitor runs outbound-only
- **Residual Risk** : Very low (no exposed services, only outbound API calls)

---

### Layer 4 : API Key Management

#### File Permissions
```bash
# Verify environment file is secure
ls -la ~/.asana-monitor-env
# Should show: -rw------- (600) = only owner can read/write

# Fix if needed
chmod 600 ~/.asana-monitor-env

# Verify no other copies exist
find ~ -name "*asana-monitor-env*" -o -name "*api*key*" 2>/dev/null | grep -v .git
```

#### Key Rotation Schedule
| API Provider | Rotation Frequency | Notes |
|--------------|-------------------|-------|
| Asana | Every 90 days | Generate new PAT in Asana settings |
| Attio | Every 90 days | Regenerate in Attio workspace settings |
| OpenAI | Every 90 days | Create new key, delete old in OpenAI dashboard |
| Anthropic | Every 90 days | Rotate in Claude console |
| Harmonic | Every 90 days | Contact support if needed |
| Perplexity | Every 90 days | Regenerate in Perplexity settings |
| Gemini | Every 90 days | Google Cloud Console |

#### Rotation Process
```bash
# 1. Generate new key in provider dashboard
# 2. Update ~/.asana-monitor-env with new key
nano ~/.asana-monitor-env

# 3. Restart monitor
launchctl unload ~/Library/LaunchAgents/com.theory.asana-monitor.plist
launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist

# 4. Test with sample task
# 5. Delete old key from provider dashboard (NOT before testing!)

# 6. Log rotation event
echo "[$(date)] API keys rotated" >> ~/Documents/coding/asana-agent-monitor/logs/security.log
```

#### Best Practices
- [ ] Store keys in `~/.asana-monitor-env` only (not in code or git)
- [ ] Use 600 permissions (owner read/write only)
- [ ] Rotate keys every 90 days
- [ ] Monitor API usage for anomalies
- [ ] Use separate API keys for M1 Mac (if provider supports)
- [ ] Never commit keys to git or share via email/chat
- [ ] Use password manager for backup (1Password, Bitwarden)

#### Key Leakage Scenarios
- **Scenario** : API keys leaked through logs, backups, or git
- **Mitigation** : 600 permissions, .gitignore, log scrubbing
- **Residual Risk** : Low-medium (depends on backup & git hygiene)

---

### Layer 5 : Application Security

#### Log Sanitization
```bash
# Create log scrubbing script
nano ~/.gemini/bin/scrub_logs.sh
```

```bash
#!/bin/bash
# Scrub sensitive data from logs

LOG_DIR="$HOME/Documents/coding/asana-agent-monitor/logs"

# Patterns to redact (API keys, tokens, emails)
PATTERNS=(
    's/Bearer [A-Za-z0-9_\-\.]+/Bearer [REDACTED]/g'
    's/api[_-]?key["\s:=]+[A-Za-z0-9_\-\.]+/api_key [REDACTED]/g'
    's/token["\s:=]+[A-Za-z0-9_\-\.]+/token [REDACTED]/g'
    's/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[A-Z|a-z]{2,}/email@redacted.com/g'
)

for log in "$LOG_DIR"/*.log; do
    if [ -f "$log" ]; then
        for pattern in "${PATTERNS[@]}"; do
            sed -i '' "$pattern" "$log"
        done
    fi
done

echo "[$(date)] Logs scrubbed"
```

Make executable & schedule:
```bash
chmod +x ~/.gemini/bin/scrub_logs.sh

# Add to crontab (run daily at 3am)
crontab -e
# Add: 0 3 * * * /Users/YOUR_USERNAME/.gemini/bin/scrub_logs.sh
```

#### Dependency Security
```bash
# Update Ruby gems regularly
gem update

# Check for security vulnerabilities
gem install bundler-audit
cd ~/Documents/coding/asana-agent-monitor
bundler-audit check --update

# Update system packages
brew update && brew upgrade
```

#### Best Practices
- [ ] Scrub logs daily to remove sensitive data
- [ ] Update dependencies monthly
- [ ] Review code changes before pulling updates
- [ ] Use HTTPS for all API calls (verify in code)
- [ ] Validate API responses (prevent injection attacks)
- [ ] Limit error messages (don't expose internals)

---

### Layer 6 : Monitoring & Alerting

#### Anomaly Detection
```bash
# Create monitoring script
nano ~/.gemini/bin/security_monitor.sh
```

```bash
#!/bin/bash
# Security monitoring for Asana agent

LOG_FILE="$HOME/Documents/coding/asana-agent-monitor/logs/security.log"
AGENT_LOG="$HOME/Documents/coding/asana-agent-monitor/logs/agent.log"

# Check for API authentication failures
AUTH_FAILURES=$(grep -c "401 Unauthorized\|403 Forbidden" "$AGENT_LOG")
if [ "$AUTH_FAILURES" -gt 5 ]; then
    echo "[$(date)] ⚠️ HIGH ALERT: $AUTH_FAILURES API auth failures detected" >> "$LOG_FILE"
    # Optional: Send email/notification
fi

# Check for unusual API volume
HOURLY_CALLS=$(grep -c "API call" "$AGENT_LOG" | tail -1)
if [ "$HOURLY_CALLS" -gt 100 ]; then
    echo "[$(date)] ⚠️ ALERT: Unusual API volume ($HOURLY_CALLS calls/hour)" >> "$LOG_FILE"
fi

# Check for disk space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "[$(date)] ⚠️ ALERT: Disk usage at $DISK_USAGE%" >> "$LOG_FILE"
fi

# Check for unexpected processes
UNEXPECTED=$(ps aux | grep -E "nc|ncat|telnet" | grep -v grep)
if [ -n "$UNEXPECTED" ]; then
    echo "[$(date)] ⚠️ HIGH ALERT: Unexpected process detected: $UNEXPECTED" >> "$LOG_FILE"
fi

echo "[$(date)] ✅ Security check completed" >> "$LOG_FILE"
```

Schedule security monitoring:
```bash
chmod +x ~/.gemini/bin/security_monitor.sh

# Run every hour
crontab -e
# Add: 0 * * * * /Users/YOUR_USERNAME/.gemini/bin/security_monitor.sh
```

#### Log Review Checklist
- [ ] Review security.log weekly
- [ ] Check for authentication failures
- [ ] Monitor API call volume
- [ ] Verify no unexpected processes
- [ ] Check disk usage trends
- [ ] Review system updates available

---

### Layer 7 : Backup & Recovery

#### Secure Backup Strategy
```bash
# Create encrypted backup script
nano ~/.gemini/bin/secure_backup.sh
```

```bash
#!/bin/bash
# Encrypted backup of Asana monitor configuration

BACKUP_DIR="$HOME/Backups/asana-monitor"
DATE=$(date +%Y%m%d)
BACKUP_FILE="$BACKUP_DIR/asana-monitor-$DATE.tar.gz.enc"

mkdir -p "$BACKUP_DIR"

# Create encrypted backup (requires password)
tar -czf - \
    ~/.asana-monitor-env \
    ~/.gemini/bin/asana_monitor_wrapper.sh \
    ~/Library/LaunchAgents/com.theory.asana-monitor.plist \
    ~/Documents/coding/asana-agent-monitor/ | \
openssl enc -aes-256-cbc -salt -pbkdf2 -out "$BACKUP_FILE"

# Remove backups older than 30 days
find "$BACKUP_DIR" -name "*.enc" -mtime +30 -delete

echo "[$(date)] Encrypted backup created: $BACKUP_FILE"
```

Restore from backup:
```bash
# Decrypt & restore
openssl enc -d -aes-256-cbc -pbkdf2 -in backup.tar.gz.enc | tar -xzf - -C /
```

#### Best Practices
- [ ] Backup configuration weekly
- [ ] Encrypt backups with strong password
- [ ] Store backups on separate encrypted drive
- [ ] Test restore process monthly
- [ ] Keep 30 days of backup history
- [ ] Never backup API keys to cloud (unless encrypted)

---

## Incident Response Plan

### If API Keys Are Compromised

1. **Immediate Actions** (within 1 hour)
   ```bash
   # Stop monitor
   launchctl unload ~/Library/LaunchAgents/com.theory.asana-monitor.plist

   # Rotate ALL API keys in provider dashboards
   # Update ~/.asana-monitor-env with new keys

   # Review API usage logs for unauthorized calls
   ```

2. **Investigation** (within 24 hours)
   - Review logs for suspicious activity
   - Check API provider dashboards for unusual usage
   - Identify how keys were compromised
   - Document timeline & impact

3. **Recovery** (within 48 hours)
   - Implement additional security controls
   - Update incident response plan
   - Notify stakeholders if data was accessed

### If M1 Mac Is Compromised

1. **Immediate Actions**
   ```bash
   # Disconnect from network
   sudo ifconfig en0 down

   # Stop all services
   launchctl unload ~/Library/LaunchAgents/*.plist
   ```

2. **Containment**
   - Rotate all API keys from another device
   - Change macOS user password
   - Review recent file modifications
   - Check for malware/unauthorized software

3. **Recovery**
   - Wipe & reinstall macOS if necessary
   - Restore from clean backup
   - Re-harden security settings
   - Resume monitoring only after verification

---

## Security Audit Checklist

### Monthly Review
- [ ] Check for unauthorized file modifications : `find ~ -mtime -30 -type f`
- [ ] Review security.log for anomalies
- [ ] Verify API key rotation schedule
- [ ] Check disk encryption status : `fdesetup status`
- [ ] Review firewall configuration
- [ ] Update system & dependencies
- [ ] Test backup restore process
- [ ] Review LaunchAgent logs for errors

### Quarterly Review
- [ ] Rotate all API keys
- [ ] Review & update security policies
- [ ] Audit user accounts & permissions
- [ ] Test incident response plan (tabletop exercise)
- [ ] Review logs for patterns/trends
- [ ] Update this security guide

### Annual Review
- [ ] Complete security assessment
- [ ] Update threat model
- [ ] Review & improve incident response plan
- [ ] Document lessons learned
- [ ] Plan security improvements for next year

---

## Compliance Considerations

### Data Privacy
- **GDPR** : If processing EU personal data, ensure compliance
- **CCPA** : If processing California resident data, ensure compliance
- **Company Policy** : Ensure monitor complies with internal policies

### Best Practices
- [ ] Document what data is processed
- [ ] Implement data retention policy (delete old logs)
- [ ] Ensure API providers are compliant
- [ ] Get approval from stakeholders before deployment
- [ ] Log access to sensitive data

---

## Additional Resources

### Security Tools
- **Malwarebytes** : Malware scanning for macOS
- **Little Snitch** : Network monitoring & firewall
- **KnockKnock** : Detect persistent malware
- **BlockBlock** : Monitor for persistent software

### Security Guides
- **OWASP Top 10** : https://owasp.org/www-project-top-ten/
- **macOS Security Guide** : https://github.com/drduh/macOS-Security-and-Privacy-Guide
- **NIST Cybersecurity Framework** : https://www.nist.gov/cyberframework

### Incident Response
- **SANS Incident Response** : https://www.sans.org/incident-response/
- **US-CERT** : https://www.cisa.gov/uscert/

---

## Summary

### Critical Security Controls (Must Have)
1. ✅ FileVault disk encryption
2. ✅ Firewall enabled (block all incoming)
3. ✅ API keys in secure file (600 permissions)
4. ✅ Regular key rotation (90 days)
5. ✅ Physical security (locked location)

### Recommended Controls (Should Have)
6. ✅ SSH key-only authentication (if SSH enabled)
7. ✅ Log scrubbing & rotation
8. ✅ Security monitoring script
9. ✅ Encrypted backups
10. ✅ Firmware password

### Optional Controls (Nice to Have)
11. ⚪ Additional network monitoring tools
12. ⚪ Intrusion detection system
13. ⚪ Separate API keys for M1 Mac
14. ⚪ Compliance documentation

---

## Conclusion

This security posture provides **defense in depth** with multiple layers protecting your API keys & data. The risk level is **low-medium** for personal/small team use, making this approach appropriate.

**Key Takeaway** : No security is perfect, but these controls make unauthorized access extremely difficult & provide rapid detection/response capabilities.

For questions or improvements, update this guide & share with the team.
