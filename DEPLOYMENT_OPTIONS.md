# Asana Agent Monitor - Deployment Options Comparison

## Quick Decision Matrix

| Factor | M1 Mac (Always-On) | Cloud Server | Dual Setup |
|--------|-------------------|--------------|-----------|
| **Cost (Annual)** | ~$10/year (electricity) | $60-240/year | ~$70/year |
| **Setup Time** | 1-2 hours | 2-4 hours | 3-5 hours |
| **Uptime** | 99%+ (if configured correctly) | 99.9%+ (SLA) | 99.9%+ (failover) |
| **Security Risk** | Low (local network) | Medium (public internet) | Low-Medium |
| **Maintenance** | Weekly checks | Monthly patches | Weekly checks |
| **Scalability** | Fixed (M1 hardware) | Flexible (upgrade plan) | Flexible |
| **Remote Access** | SSH (optional) | SSH (standard) | SSH (both) |
| **Backup/Failover** | Manual (primary laptop) | Automated snapshots | Automatic failover |
| **Debugging** | Easy (physical access) | Remote only (SSH) | Easy (both) |
| **API Key Security** | Local file only | Remote server file | Both locations |

### Recommendation
**Start with M1 Mac Always-On** (Option 1). It's simpler, cheaper, & more secure for personal use. Consider cloud if you need:
- Professional uptime SLA (99.9%+)
- Remote access from anywhere
- Automatic failover & scaling
- Multiple monitors/agents

---

## Option 1 : M1 Mac Always-On

### Architecture
```
M1 Mac (Local Network)
├── LaunchAgent Daemon (KeepAlive)
├── Ruby 3.4.3 + Claude Code CLI
├── Polls Asana every 3 minutes
└── Screen off, computer awake
```

### Pros & Cons
✅ **Pros:**
- Lowest cost (~$10/year electricity)
- Complete control over hardware
- Easy debugging (physical access)
- No external network dependencies
- API keys stay local
- Simple setup process

❌ **Cons:**
- Single point of failure
- Requires physical space
- Manual restart if power outage
- Limited to home/office network

### Best For
- Personal use
- Small team (1-5 people)
- Cost-sensitive deployments
- Security-conscious setups

### Setup Time : 1-2 hours
### Maintenance : 15 min/week

---

## Option 2 : Cloud Server (VPS)

### Architecture
```
Cloud Server (DigitalOcean/AWS/Fly.io)
├── Ubuntu 22.04 LTS
├── LaunchAgent equivalent (systemd)
├── Ruby 3.4.3 + Claude Code CLI
├── Polls Asana every 3 minutes
└── SSH access from anywhere
```

### Provider Options

#### DigitalOcean Droplet
- **Cost** : $6/month ($72/year)
- **Specs** : 1 vCPU, 1GB RAM, 25GB SSD
- **Uptime** : 99.99% SLA
- **Setup** : Standard, good docs
- **Recommendation** : Best for reliable, simple VPS

#### AWS Lightsail
- **Cost** : $5/month ($60/year)
- **Specs** : 1 vCPU, 512MB RAM, 20GB SSD
- **Uptime** : 99.99% SLA
- **Setup** : More complex (AWS ecosystem)
- **Recommendation** : If already using AWS

#### Fly.io
- **Cost** : $2-5/month ($24-60/year)
- **Specs** : 256MB RAM, shared CPU
- **Uptime** : 99.9% (no formal SLA on hobby)
- **Setup** : Modern, container-based
- **Recommendation** : Cheapest, but limited support

### Pros & Cons
✅ **Pros:**
- Professional uptime (99.9%+)
- Remote access from anywhere
- Automatic backups (provider managed)
- No physical hardware maintenance
- Scalable (upgrade plan easily)

❌ **Cons:**
- Monthly cost ($60-240/year)
- API keys on remote server
- More complex security setup
- Requires SSH key management
- Network-dependent

### Best For
- Professional/production use
- Distributed teams
- Need for high uptime SLA
- Remote access requirements

### Setup Time : 2-4 hours
### Maintenance : 30 min/month

---

## Option 3 : Dual Setup (M1 + Cloud)

### Architecture
```
Primary : M1 Mac (Local Network)
├── LaunchAgent Daemon
└── Priority : Primary monitor

Backup : Cloud Server
├── systemd service
├── Checks if M1 is responsive
└── Activates if M1 fails
```

### Implementation
```bash
# Health check script on cloud (runs every 5 minutes)
#!/bin/bash
# Check if M1 Mac monitor is active

M1_IP="192.168.1.100"  # Your M1's local IP
HEALTH_URL="http://$M1_IP:8080/health"  # Optional health endpoint

if ! curl -s --max-time 5 "$HEALTH_URL" > /dev/null; then
    # M1 is down, activate cloud monitor
    systemctl start asana-monitor
else
    # M1 is up, ensure cloud monitor is stopped
    systemctl stop asana-monitor
fi
```

### Pros & Cons
✅ **Pros:**
- Best uptime (failover if M1 fails)
- Flexibility (use M1 normally, cloud as backup)
- Cost-effective ($70/year vs $240/year for cloud-only)
- Remote access via cloud server

❌ **Cons:**
- More complex setup & management
- Two systems to maintain
- Potential for duplicate task processing (need deduplication)
- Higher overall cost than M1-only

### Best For
- Critical workflows (cannot tolerate downtime)
- Hybrid work (home office + travel)
- High-stakes task processing
- Professional teams with budget

### Setup Time : 3-5 hours
### Maintenance : 30 min/week

---

## Cloud Server Setup Guide (Option 2)

### Prerequisites
1. Cloud account (DigitalOcean, AWS, or Fly.io)
2. SSH key pair
3. Basic Linux knowledge

### Step-by-Step (DigitalOcean Example)

#### 1. Create Droplet
```bash
# Via DigitalOcean web interface:
# - Choose Ubuntu 22.04 LTS
# - Select $6/month plan (1GB RAM)
# - Add your SSH key
# - Enable backups (optional, +20% cost)
```

#### 2. Initial Server Setup
```bash
# SSH into server
ssh root@your_server_ip

# Update system
apt update && apt upgrade -y

# Create non-root user
adduser asanamonitor
usermod -aG sudo asanamonitor

# Copy SSH key to new user
rsync --archive --chown=asanamonitor:asanamonitor ~/.ssh /home/asanamonitor

# Switch to new user
su - asanamonitor
```

#### 3. Install Dependencies
```bash
# Install Ruby via rbenv
sudo apt install -y git curl libssl-dev libreadline-dev zlib1g-dev \
  autoconf bison build-essential libyaml-dev libreadline-dev \
  libncurses5-dev libffi-dev libgdbm-dev

curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash

echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
source ~/.bashrc

rbenv install 3.4.3
rbenv global 3.4.3

# Install required gems
gem install net-http json logger
```

#### 4. Install Claude Code CLI
```bash
# Follow Anthropic's installation guide
# (varies by distribution)
```

#### 5. Copy Project Files
```bash
# From your local machine:
cd ~/Documents/coding/asana-agent-monitor
tar -czf asana-monitor.tar.gz .

# Upload to server
scp asana-monitor.tar.gz asanamonitor@your_server_ip:~/

# On server:
mkdir -p ~/asana-agent-monitor
cd ~/asana-agent-monitor
tar -xzf ~/asana-monitor.tar.gz
```

#### 6. Configure Environment
```bash
# Create secure environment file
nano ~/.asana-monitor-env
# (Copy contents from local Mac)

chmod 600 ~/.asana-monitor-env
```

#### 7. Create systemd Service
```bash
sudo nano /etc/systemd/system/asana-monitor.service
```

Add:
```ini
[Unit]
Description=Asana Agent Monitor
After=network.target

[Service]
Type=simple
User=asanamonitor
WorkingDirectory=/home/asanamonitor/asana-agent-monitor
Environment="PATH=/home/asanamonitor/.rbenv/shims:/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=/home/asanamonitor/.asana-monitor-env
ExecStart=/home/asanamonitor/.rbenv/versions/3.4.3/bin/ruby /home/asanamonitor/asana-agent-monitor/bin/monitor.rb
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable & start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable asana-monitor
sudo systemctl start asana-monitor

# Check status
sudo systemctl status asana-monitor

# View logs
journalctl -u asana-monitor -f
```

#### 8. Configure Firewall
```bash
# Enable UFW firewall
sudo ufw allow OpenSSH
sudo ufw enable

# Verify
sudo ufw status
```

#### 9. Set Up Backups (Optional)
```bash
# Create backup script
nano ~/backup.sh
```

```bash
#!/bin/bash
# Backup Asana monitor configuration

tar -czf ~/asana-monitor-backup-$(date +%Y%m%d).tar.gz \
  ~/.asana-monitor-env \
  ~/asana-agent-monitor/

# Upload to S3/Backblaze/etc (optional)
# aws s3 cp ~/asana-monitor-backup-$(date +%Y%m%d).tar.gz s3://your-bucket/

# Clean old backups (keep 7 days)
find ~ -name "asana-monitor-backup-*.tar.gz" -mtime +7 -delete
```

Schedule daily:
```bash
crontab -e
# Add: 0 3 * * * /home/asanamonitor/backup.sh
```

---

## Security Comparison

| Security Control | M1 Mac | Cloud Server |
|------------------|--------|--------------|
| **Disk Encryption** | FileVault | LUKS (manual setup) |
| **Network Exposure** | Local only | Public IP (firewall required) |
| **API Key Storage** | Local file (600) | Remote file (600) + SSH keys |
| **Physical Access** | You control | Provider controls |
| **Update Management** | macOS auto-update | Manual apt updates |
| **Incident Response** | Physical access | SSH only |
| **Backup Security** | Local encrypted | Cloud storage (provider dependent) |
| **Compliance** | Simpler (local) | More complex (remote data) |

### Security Hardening for Cloud

#### Essential Steps
1. **SSH Hardening**
   - Disable password auth
   - Use SSH keys only
   - Change default port (optional)
   - Enable fail2ban

2. **Firewall**
   - Enable UFW
   - Allow only SSH & essential services
   - Block all other incoming

3. **Monitoring**
   - Set up log aggregation (rsyslog)
   - Enable intrusion detection (fail2ban)
   - Monitor API usage

4. **Updates**
   ```bash
   # Enable automatic security updates
   sudo apt install unattended-upgrades
   sudo dpkg-reconfigure --priority=low unattended-upgrades
   ```

5. **Backup Encryption**
   ```bash
   # Encrypt backups before upload
   tar -czf - ~/asana-agent-monitor | \
     openssl enc -aes-256-cbc -salt -out backup.tar.gz.enc
   ```

---

## Cost-Benefit Analysis

### 1-Year Total Cost of Ownership

| Component | M1 Mac | Cloud (DO) | Dual Setup |
|-----------|--------|-----------|-----------|
| **Setup Time** | 2 hours × $50/hr = $100 | 4 hours × $50/hr = $200 | 5 hours × $50/hr = $250 |
| **Monthly Cost** | $0.85/month | $6/month | $6.85/month |
| **Annual Recurring** | $10 | $72 | $82 |
| **Maintenance** | 12 hours × $50/hr = $600 | 6 hours × $50/hr = $300 | 15 hours × $50/hr = $750 |
| **Total (Year 1)** | **$710** | **$572** | **$1,082** |
| **Total (Year 2+)** | **$610** | **$372** | **$832** |

*Assumes $50/hour value of your time*

### Break-Even Analysis
- **Cloud vs M1** : Cloud is cheaper if you value your time (less maintenance)
- **M1 only** : Best if you enjoy tinkering & want full control
- **Dual setup** : Only worth it if uptime is critical ($$$ cost of downtime)

---

## Migration Path

### Phase 1 : Start with M1 Mac (Week 1)
1. Complete M1 setup (1-2 hours)
2. Test with sample tasks
3. Monitor for 1 week
4. Evaluate stability

### Phase 2 : Assess Need (Week 2-4)
- **If stable & happy** : Stay with M1, done!
- **If reliability issues** : Proceed to Phase 3
- **If need remote access** : Proceed to Phase 3

### Phase 3 : Add Cloud Backup (Month 2)
1. Set up cloud server (2-4 hours)
2. Configure as passive backup
3. Test failover manually
4. Monitor both systems

### Phase 4 : Optimize (Month 3+)
- Decide if dual setup is worth the cost
- Consolidate to one system or keep both
- Automate more monitoring/alerting

---

## Troubleshooting Comparison

| Issue | M1 Mac | Cloud Server |
|-------|--------|--------------|
| **Process Dies** | Check LaunchAgent, restart locally | SSH in, check systemd, restart remotely |
| **API Key Invalid** | Edit local file, restart | SSH in, edit file, restart service |
| **Network Issue** | Check local router/ISP | Check cloud provider status page |
| **Disk Full** | Free up space, physical access | SSH in, clean logs, resize disk (extra cost) |
| **System Update** | macOS auto-update or manual | SSH in, apt update/upgrade |
| **Debugging** | Run manually in Terminal | SSH in, check journalctl logs |

---

## Final Recommendation

### For Most Users : M1 Mac Always-On
**Reasons:**
- Lowest cost over 2+ years
- Complete control & security
- Easy debugging & maintenance
- No external dependencies

**When to choose Cloud instead:**
- You travel frequently & need remote access
- You need professional uptime SLA
- You already use cloud infrastructure
- You want automatic backups & monitoring

**When to choose Dual Setup:**
- Task processing is business-critical
- Cost of downtime exceeds $800/year
- You need 99.9%+ uptime guarantee
- You want best of both worlds

---

## Next Steps

1. **Review this guide** & choose deployment option
2. **Follow setup guide** (M1_SETUP_GUIDE.md or this doc)
3. **Implement security hardening** (SECURITY_HARDENING.md)
4. **Test thoroughly** for 1-2 weeks
5. **Evaluate & adjust** based on experience

For questions, refer to:
- `M1_SETUP_GUIDE.md` : Detailed M1 Mac setup
- `SECURITY_HARDENING.md` : Security best practices
- `README.md` : System architecture & usage
- `QUICK_START.md` : Feature documentation
