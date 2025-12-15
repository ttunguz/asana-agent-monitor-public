# M1 Automated Setup - Complete Package

## 📦 What's Included

I've created a complete automated setup system for your M1 Mac. Here's everything that was added to the repository:

### 1. **setup_m1.sh** (19 KB) - Main Setup Script
**Purpose**: Fully automated installation & configuration script

**What it does**:
- ✅ Installs Homebrew (if needed)
- ✅ Installs Ruby 3.4.3 via rbenv (if needed)
- ✅ Installs required gems
- ✅ Creates secure environment file (600 permissions)
- ✅ Generates wrapper scripts with correct paths
- ✅ Configures LaunchAgent daemon
- ✅ Sets up sleep prevention
- ✅ Creates health monitoring script
- ✅ Tests & verifies everything works
- ✅ Provides detailed status output

**Usage**:
```bash
cd ~/Documents/coding/asana-agent-monitor
./setup_m1.sh
```

**Time**: 15-30 minutes (mostly automated)

**Options**:
- `--skip-homebrew` - Skip Homebrew installation
- `--skip-ruby` - Skip Ruby installation
- `--source-path PATH` - Specify source files location
- `--help` - Show usage information

---

### 2. **M1_SETUP_README.md** (9.6 KB) - Quick Start Guide
**Purpose**: User-friendly documentation for the automated setup

**Covers**:
- Quick start instructions
- Transfer methods (AirDrop, Git, Network)
- Script options & flags
- Troubleshooting common issues
- Post-setup verification
- Maintenance commands
- Backup & recovery
- Uninstall instructions

**Best for**: Quick reference during setup

---

### 3. **M1_SETUP_CHECKLIST.md** (6.8 KB) - Printable Checklist
**Purpose**: Step-by-step checklist for setup & verification

**Includes**:
- Pre-setup requirements
- Setup process checklist
- Verification commands
- Security checks
- Post-setup tasks
- Maintenance reminders
- Emergency procedures
- Success criteria

**Best for**: Print & check off items as you go

---

### 4. **M1_SETUP_GUIDE.md** (Already existed) - Complete Manual Guide
**Purpose**: Detailed manual setup instructions (for reference)

**Covers**:
- Manual step-by-step setup
- Architecture overview
- Deployment options comparison
- Comprehensive troubleshooting
- Cost analysis
- Security safeguards

**Best for**: Understanding internals or manual setup if script fails

---

## 🚀 Quick Start (3 Steps)

### Step 1: Transfer Files to M1 Mac

**Option A: AirDrop** (Easiest)
```bash
# On primary laptop
cd ~/Documents/coding/asana-agent-monitor
tar -czf asana-monitor.tar.gz .
# AirDrop to M1 Mac

# On M1 Mac
mkdir -p ~/Documents/coding/asana-agent-monitor
cd ~/Documents/coding/asana-agent-monitor
tar -xzf ~/Downloads/asana-monitor.tar.gz
```

**Option B: Git**
```bash
git clone <your-repo> ~/Documents/coding/asana-agent-monitor
```

### Step 2: Run Setup Script
```bash
cd ~/Documents/coding/asana-agent-monitor
./setup_m1.sh
```

The script will:
1. Install dependencies (Homebrew, Ruby, gems)
2. Prompt for API keys
3. Create secure configuration
4. Set up LaunchAgent daemon
5. Configure sleep prevention
6. Test & verify everything

### Step 3: Configure System Settings
After script completes, manually configure:
1. **FileVault**: System Settings → Privacy & Security → FileVault → Turn On
2. **Firewall**: System Settings → Network → Firewall → Turn On
3. **Energy Saver**: System Settings → Battery
   - Turn display off after: 10 minutes
   - Prevent automatic sleeping when display is off: ON
   - Put hard disks to sleep: OFF

Done! Your M1 Mac is now monitoring 24/7.

---

## 📊 What Gets Installed

### System Requirements
- **macOS**: 11+ (Big Sur or later)
- **Processor**: Apple M1/M2/M3
- **Disk Space**: ~500 MB (Ruby + dependencies)
- **RAM**: 2 GB available
- **Network**: Internet connection

### Installed Components
- **Homebrew**: Package manager (`/opt/homebrew`)
- **rbenv**: Ruby version manager (`~/.rbenv`)
- **Ruby 3.4.3**: Via rbenv
- **Gems**: net-http, json, logger

### Created Files & Directories
```
~/.asana-monitor-env                    # Secure env file (600)
~/.gemini/bin/
  ├── asana_monitor_wrapper.sh         # LaunchAgent wrapper
  └── monitor_health.sh                 # Health check script
~/Library/LaunchAgents/
  ├── com.theory.asana-monitor.plist    # Main daemon
  └── com.theory.prevent-sleep.plist    # Sleep prevention
~/Documents/coding/asana-agent-monitor/ # Project files
  ├── bin/monitor.rb                    # Main script
  ├── lib/                              # Libraries
  ├── logs/                             # Log files
  └── config/                           # Configuration
```

---

## 🔒 Security Features

### Automated Security
- ✅ Environment file with 600 permissions (owner-only access)
- ✅ API keys never exposed in code or logs
- ✅ Secure wrapper scripts
- ✅ Log scrubbing for sensitive data
- ✅ Proper PATH isolation

### Manual Security (Prompts in Script)
- ⚙️ FileVault disk encryption
- ⚙️ Firewall configuration
- ⚙️ Physical security (secure location)
- ⚙️ Strong user password

### Security Verification
```bash
# Check environment file permissions
ls -la ~/.asana-monitor-env
# Should show: -rw------- (600)

# Verify FileVault
fdesetup status
# Should show: FileVault is On

# Verify Firewall
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
# Should show: enabled
```

---

## 🧪 Testing & Verification

### Automated Tests (Built into Script)
1. Manual test run before LaunchAgent load
2. LaunchAgent plist validation
3. Process startup verification
4. Health check execution

### Manual Verification (Post-Setup)
```bash
# 1. Check LaunchAgent status
launchctl list | grep asana
# Should show PID (not 78)

# 2. Check process
ps aux | grep monitor.rb | grep -v grep
# Should show ruby process running

# 3. Run health check
~/.gemini/bin/monitor_health.sh
# Should show ✅ Monitor running

# 4. View logs
tail -f ~/Documents/coding/asana-agent-monitor/logs/agent.log
# Should show polling activity
```

### Real-World Test
1. Go to https://app.asana.com/0/1211959613518208
2. Create task: "Test: What is 2+2?"
3. Wait 3 minutes (polling interval)
4. Check for agent response

---

## 📈 Monitoring & Maintenance

### Daily (Automated)
- LaunchAgent KeepAlive ensures process runs continuously
- Automatic restart on crash
- Log rotation (prevents disk fill)

### Weekly (5 minutes)
```bash
# Run health check
~/.gemini/bin/monitor_health.sh

# Check for errors
grep ERROR ~/Documents/coding/asana-agent-monitor/logs/agent.log
```

### Monthly (15 minutes)
```bash
# Update gems
gem update

# Check disk space
df -h

# Review logs
tail -100 ~/Documents/coding/asana-agent-monitor/logs/agent.log
```

### Quarterly (30 minutes)
- Rotate API keys
- Test failover to primary laptop
- Review & optimize
- Update Ruby version (if needed)

---

## 💰 Cost Analysis

### M1 Mac Always-On
- **Power consumption**: ~10W idle
- **Annual electricity**: 87.6 kWh
- **Cost**: $10.51/year @ $0.12/kWh

### Time Investment
- **Setup**: 15-30 minutes (one-time)
- **Weekly**: 5 minutes (health check)
- **Monthly**: 15 minutes (maintenance)
- **Quarterly**: 30 minutes (API rotation)
- **Total Year 1**: ~3.5 hours

### Comparison vs Cloud
| Option | Setup | Cost/Year | Maintenance | Security |
|--------|-------|-----------|-------------|----------|
| M1 Mac | 30 min | $10 | 1 hr/month | High (local) |
| DigitalOcean | 2 hrs | $72 | 2 hr/month | Medium (cloud) |
| AWS Lightsail | 2 hrs | $60 | 2 hr/month | Medium (cloud) |

**Winner**: M1 Mac - 85% cost savings & better security

---

## 🛠️ Troubleshooting

### Common Issues & Solutions

#### Setup Script Fails
```bash
# Check script permissions
ls -la setup_m1.sh
# Should be: -rwxr-xr-x

# Make executable if needed
chmod +x setup_m1.sh
```

#### Ruby Installation Times Out
```bash
# Install manually first
brew install rbenv ruby-build
rbenv install 3.4.3
rbenv global 3.4.3

# Run setup with --skip-ruby
./setup_m1.sh --skip-ruby
```

#### LaunchAgent Won't Load
```bash
# Validate plist syntax
plutil ~/Library/LaunchAgents/com.theory.asana-monitor.plist

# Check LaunchAgent logs
tail -50 ~/Library/Logs/com.theory.asana-monitor.log

# Manually test wrapper
~/.gemini/bin/asana_monitor_wrapper.sh
```

#### Process Dies Immediately
```bash
# Test manually to see errors
~/.rbenv/versions/3.4.3/bin/ruby ~/Documents/coding/asana-agent-monitor/bin/monitor.rb

# Check API keys
cat ~/.asana-monitor-env
source ~/.asana-monitor-env
echo $ASANA_API_KEY
```

#### M1 Mac Keeps Sleeping
```bash
# Verify caffeinate is running
ps aux | grep caffeinate

# Alternative: use pmset
sudo pmset -a sleep 0
sudo pmset -a disksleep 0
```

---

## 🔄 Backup & Recovery

### Create Backup
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

### Failover to Primary Laptop
```bash
# On primary laptop (emergency fallback)
launchctl load ~/Library/LaunchAgents/com.theory.asana-monitor.plist
```

---

## 📝 Script Features

### Intelligent Defaults
- Skips already-installed components
- Validates all configurations
- Provides clear error messages
- Colorized output for readability

### Safety Checks
- Backs up existing configurations
- Validates plist syntax
- Tests before enabling LaunchAgent
- Verifies process startup

### User Experience
- Progress indicators
- Clear prompts for user input
- Helpful error recovery suggestions
- Comprehensive status summary

### Error Handling
- Exits on critical errors
- Provides troubleshooting hints
- Logs all actions
- Rollback on failure (where possible)

---

## ✅ Success Criteria

Your M1 Mac setup is complete & successful when:

1. ✅ Script completes without errors
2. ✅ LaunchAgent shows running PID
3. ✅ Monitor process visible in `ps aux`
4. ✅ Health check returns green status
5. ✅ Test Asana task receives agent response
6. ✅ System stays awake overnight
7. ✅ FileVault & Firewall enabled
8. ✅ Environment file has 600 permissions
9. ✅ No errors in logs for 24 hours
10. ✅ Maintenance reminders set

---

## 🎯 Next Steps After Setup

### Immediate (Today)
1. Run setup script
2. Complete manual security configuration
3. Test with sample Asana task
4. Verify logs showing activity

### Tomorrow
1. Check health status
2. Review logs for any errors
3. Verify system stayed awake overnight

### This Week
1. Monitor stability for 7 days
2. Disable monitor on primary laptop (once confident)
3. Document any issues or customizations

### This Month
1. Set calendar reminders for maintenance
2. Create backup of configuration
3. Test failover to primary laptop

---

## 📚 Documentation Index

Choose the right documentation for your needs:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **M1_SETUP_README.md** | Quick start guide | Starting setup |
| **M1_SETUP_CHECKLIST.md** | Printable checklist | During setup |
| **M1_SETUP_GUIDE.md** | Complete manual guide | Understanding details |
| **SECURITY_HARDENING.md** | Security best practices | After setup |
| **DEPLOYMENT_OPTIONS.md** | Comparison of options | Before choosing approach |

---

## 🆘 Getting Help

### Self-Service Troubleshooting
1. Check **M1_SETUP_README.md** - Troubleshooting section
2. Check **M1_SETUP_GUIDE.md** - Detailed troubleshooting
3. Review logs:
   - Agent log: `~/Documents/coding/asana-agent-monitor/logs/agent.log`
   - LaunchAgent log: `~/Library/Logs/com.theory.asana-monitor.log`
4. Run health check: `~/.gemini/bin/monitor_health.sh`

### Manual Testing
```bash
# Test wrapper script
~/.gemini/bin/asana_monitor_wrapper.sh

# Test Ruby script directly
source ~/.asana-monitor-env
ruby ~/Documents/coding/asana-agent-monitor/bin/monitor.rb
```

---

## 🎉 Summary

You now have a **production-ready automated setup system** for your M1 Mac:

### What You Get
✅ **Fully automated setup** (15-30 minutes)
✅ **Comprehensive documentation** (4 guides)
✅ **Security best practices** (600 permissions, encryption)
✅ **Health monitoring** (auto-restart on failure)
✅ **Maintenance tools** (health check, log rotation)
✅ **Backup & recovery** (documented procedures)
✅ **Cost-effective** (~$10/year vs $60-240 for cloud)

### Key Benefits
- **Simple**: Run one script, answer a few prompts
- **Secure**: Industry-standard security practices
- **Reliable**: LaunchAgent KeepAlive architecture
- **Maintainable**: Clear documentation & tools
- **Cost-effective**: 85% savings vs cloud hosting

### Time to Value
- **15-30 minutes**: Setup complete
- **3 minutes**: First test task answered
- **24 hours**: Proven stability
- **1 week**: Fully operational & trusted

---

**Ready to get started?**

```bash
cd ~/Documents/coding/asana-agent-monitor
./setup_m1.sh
```

**Questions?** Check `M1_SETUP_README.md` for detailed documentation.

**Issues?** See troubleshooting sections in any of the guides.

**Happy monitoring!** 🚀
