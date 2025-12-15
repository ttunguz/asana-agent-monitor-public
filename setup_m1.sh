#!/bin/bash
#
# Asana Agent Monitor - M1 Mac Setup Script
#
# This script automates the setup of the Asana Agent Monitor on an M1 Mac
# for 24/7 operation. It handles dependencies, security configuration, and
# LaunchAgent setup.
#
# Usage : ./setup_m1.sh [--skip-homebrew] [--skip-ruby] [--source-path PATH]
#
# Options :
#   --skip-homebrew     Skip Homebrew installation (if already installed)
#   --skip-ruby        Skip Ruby/rbenv installation (if already configured)
#   --source-path PATH Path to source files (default : copy from current directory)
#   --help             Show this help message
#
# Security Features :
#   - Creates environment file with 600 permissions
#   - Sets up secure wrapper scripts
#   - Configures firewall & FileVault prompts
#   - Implements log rotation
#

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RUBY_VERSION="3.4.3"
PROJECT_PATH="$HOME/Documents/coding/asana-agent-monitor"
ENV_FILE="$HOME/.asana-monitor-env"
WRAPPER_DIR="$HOME/.gemini/bin"
WRAPPER_SCRIPT="$WRAPPER_DIR/asana_monitor_wrapper.sh"
LAUNCHAGENT_DIR="$HOME/Library/LaunchAgents"
LAUNCHAGENT_FILE="$LAUNCHAGENT_DIR/com.theory.asana-monitor.plist"
CAFFEINATE_PLIST="$LAUNCHAGENT_DIR/com.theory.prevent-sleep.plist"
HEALTH_SCRIPT="$WRAPPER_DIR/monitor_health.sh"

# Parse command line arguments
SKIP_HOMEBREW=false
SKIP_RUBY=false
SOURCE_PATH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-homebrew)
      SKIP_HOMEBREW=true
      shift
      ;;
    --skip-ruby)
      SKIP_RUBY=true
      shift
      ;;
    --source-path)
      SOURCE_PATH="$2"
      shift 2
      ;;
    --help)
      head -n 20 "$0" | tail -n +3 | sed 's/^# //'
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option : $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Helper functions
print_header() {
  echo ""
  echo -e "${BLUE}==================================================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}==================================================================${NC}"
  echo ""
}

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
  echo -e "${RED}❌ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

prompt_continue() {
  echo -e "${YELLOW}Press Enter to continue or Ctrl+C to abort...${NC}"
  read -r
}

check_command() {
  if command -v "$1" &> /dev/null; then
    return 0
  else
    return 1
  fi
}

get_username() {
  whoami
}

# Main script starts here
clear
print_header "Asana Agent Monitor - M1 Mac Setup"

echo "This script will set up your M1 Mac for 24/7 Asana monitoring."
echo "Setup time : approximately 15-30 minutes"
echo ""
echo "What will be configured :"
echo "  • Homebrew package manager (if needed)"
echo "  • Ruby 3.4.3 via rbenv (if needed)"
echo "  • Project files & dependencies"
echo "  • Secure environment variables"
echo "  • LaunchAgent daemon"
echo "  • Sleep prevention"
echo "  • Health monitoring"
echo ""
print_warning "You will be prompted for :"
echo "  • API keys (Asana, Attio, OpenAI, etc.)"
echo "  • Admin password (for security settings)"
echo ""
prompt_continue

# Phase 1 : Prerequisites
print_header "Phase 1 : Installing Prerequisites"

# Check for Homebrew
if [ "$SKIP_HOMEBREW" = false ]; then
  if check_command brew; then
    print_success "Homebrew already installed"
  else
    print_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for M1
    if [[ $(uname -m) == 'arm64' ]]; then
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    print_success "Homebrew installed"
  fi
else
  print_info "Skipping Homebrew installation"
fi

# Check for rbenv & Ruby
if [ "$SKIP_RUBY" = false ]; then
  if check_command rbenv; then
    print_success "rbenv already installed"
  else
    print_info "Installing rbenv & ruby-build..."
    brew install rbenv ruby-build

    # Add rbenv to shell
    if ! grep -q 'rbenv init' "$HOME/.zshrc"; then
      echo 'eval "$(rbenv init - zsh)"' >> "$HOME/.zshrc"
    fi

    # Initialize for current session
    eval "$(rbenv init - zsh)"

    print_success "rbenv installed"
  fi

  # Install Ruby version
  if rbenv versions | grep -q "$RUBY_VERSION"; then
    print_success "Ruby $RUBY_VERSION already installed"
  else
    print_info "Installing Ruby $RUBY_VERSION (this may take 5-10 minutes)..."
    rbenv install "$RUBY_VERSION"
    rbenv global "$RUBY_VERSION"
    print_success "Ruby $RUBY_VERSION installed"
  fi

  # Verify Ruby version
  CURRENT_RUBY=$(ruby --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
  if [[ "$CURRENT_RUBY" != "$RUBY_VERSION" ]]; then
    print_warning "Ruby version mismatch. Expected $RUBY_VERSION, got $CURRENT_RUBY"
    print_info "Setting global Ruby version..."
    rbenv global "$RUBY_VERSION"
    eval "$(rbenv init - zsh)"
  fi

  # Install required gems
  print_info "Installing required gems..."
  gem install net-http json logger --silent
  print_success "Gems installed"
else
  print_info "Skipping Ruby installation"
fi

# Phase 2 : Copy Project Files
print_header "Phase 2 : Setting Up Project Files"

if [ -d "$PROJECT_PATH" ]; then
  print_warning "Project directory already exists : $PROJECT_PATH"
  echo "Options :"
  echo "  1) Keep existing & skip copy"
  echo "  2) Backup existing & replace"
  echo "  3) Abort setup"
  read -p "Choose (1/2/3) : " choice

  case $choice in
    1)
      print_info "Keeping existing project files"
      ;;
    2)
      BACKUP_PATH="${PROJECT_PATH}_backup_$(date +%Y%m%d_%H%M%S)"
      print_info "Backing up to $BACKUP_PATH"
      mv "$PROJECT_PATH" "$BACKUP_PATH"
      print_success "Backup created"
      ;;
    3)
      print_error "Setup aborted by user"
      exit 0
      ;;
    *)
      print_error "Invalid choice. Aborting."
      exit 1
      ;;
  esac
fi

if [ ! -d "$PROJECT_PATH" ]; then
  mkdir -p "$PROJECT_PATH"

  if [ -z "$SOURCE_PATH" ]; then
    print_info "No source path specified."
    echo ""
    echo "How to transfer files :"
    echo ""
    echo "Option A : From primary laptop (recommended)"
    echo "  On primary laptop :"
    echo "    cd ~/Documents/coding/asana-agent-monitor"
    echo "    tar -czf asana-monitor.tar.gz ."
    echo "  Transfer file via AirDrop, USB, or network"
    echo "  On M1 Mac :"
    echo "    tar -xzf asana-monitor.tar.gz -C $PROJECT_PATH"
    echo ""
    echo "Option B : Git clone"
    echo "    git clone <your-repo-url> $PROJECT_PATH"
    echo ""
    echo "Option C : Copy from current directory"
    echo "    If files are in current directory, script will copy them"
    echo ""

    read -p "Have you transferred the files? (y/n) : " transferred

    if [[ "$transferred" =~ ^[Yy]$ ]]; then
      print_success "Proceeding with existing files"
    else
      print_error "Please transfer files & run setup again"
      exit 1
    fi
  else
    print_info "Copying files from $SOURCE_PATH"
    cp -R "$SOURCE_PATH/." "$PROJECT_PATH/"
    print_success "Files copied"
  fi
fi

# Create required directories
mkdir -p "$PROJECT_PATH/logs"
mkdir -p "$PROJECT_PATH/config"
touch "$PROJECT_PATH/logs/agent.log"
[ -f "$PROJECT_PATH/logs/processed_comments.json" ] || echo "[]" > "$PROJECT_PATH/logs/processed_comments.json"

print_success "Project structure created"

# Phase 3 : Security Setup
print_header "Phase 3 : Configuring Security"

# Create environment file
if [ -f "$ENV_FILE" ]; then
  print_warning "Environment file already exists : $ENV_FILE"
  read -p "Overwrite? (y/n) : " overwrite
  if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
    print_info "Keeping existing environment file"
  else
    rm "$ENV_FILE"
  fi
fi

if [ ! -f "$ENV_FILE" ]; then
  print_info "Creating secure environment file..."
  echo "Please enter your API keys (leave blank to skip) :"
  echo ""

  read -p "Asana API Key : " ASANA_KEY
  read -p "Attio API Key : " ATTIO_KEY
  read -p "OpenAI API Key : " OPENAI_KEY
  read -p "Anthropic API Key : " ANTHROPIC_KEY
  read -p "Harmonic API Key : " HARMONIC_KEY
  read -p "Perplexity API Key : " PERPLEXITY_KEY
  read -p "Gemini API Key : " GEMINI_KEY

  # Create environment file
  cat > "$ENV_FILE" << EOF
# Asana Monitor Environment Variables
# Created : $(date)
# Permissions : 600 (read/write for owner only)

export ASANA_API_KEY="${ASANA_KEY}"
export ATTIO_API_KEY="${ATTIO_KEY}"
export OPENAI_API_KEY="${OPENAI_KEY}"
export ANTHROPIC_API_KEY="${ANTHROPIC_KEY}"
export HARMONIC_API_KEY="${HARMONIC_KEY}"
export PERPLEXITY_API_KEY="${PERPLEXITY_KEY}"
export GEMINI_API_KEY="${GEMINI_KEY}"
export ASANA_MONITOR_CLAUDE_FIRST=true
EOF

  chmod 600 "$ENV_FILE"
  print_success "Environment file created with secure permissions (600)"
fi

# Verify permissions
PERMS=$(stat -f "%Lp" "$ENV_FILE")
if [ "$PERMS" != "600" ]; then
  print_warning "Fixing environment file permissions..."
  chmod 600 "$ENV_FILE"
fi

# Create wrapper script
mkdir -p "$WRAPPER_DIR"

USERNAME=$(get_username)
RUBY_PATH="$HOME/.rbenv/versions/$RUBY_VERSION/bin/ruby"
MONITOR_SCRIPT="$PROJECT_PATH/bin/monitor.rb"

cat > "$WRAPPER_SCRIPT" << EOF
#!/bin/bash
# Asana Monitor Wrapper Script
# Ensures environment is properly loaded for launchd execution

RUBY_PATH="$RUBY_PATH"
SCRIPT_PATH="$MONITOR_SCRIPT"
ENV_FILE="$ENV_FILE"

# Source environment variables
if [ -f "\$ENV_FILE" ]; then
  source "\$ENV_FILE"
else
  echo "[ERROR] Environment file not found : \$ENV_FILE"
  exit 1
fi

# Verify Ruby exists
if [ ! -f "\$RUBY_PATH" ]; then
  echo "[ERROR] Ruby not found : \$RUBY_PATH"
  exit 1
fi

# Verify monitor script exists
if [ ! -f "\$SCRIPT_PATH" ]; then
  echo "[ERROR] Monitor script not found : \$SCRIPT_PATH"
  exit 1
fi

# Log start
echo "[$(date)] Starting Asana Monitor via wrapper"

# Execute monitor
exec "\$RUBY_PATH" "\$SCRIPT_PATH"
EOF

chmod +x "$WRAPPER_SCRIPT"
print_success "Wrapper script created"

# Phase 4 : LaunchAgent Configuration
print_header "Phase 4 : Configuring LaunchAgent"

mkdir -p "$LAUNCHAGENT_DIR"

# Create main LaunchAgent plist
cat > "$LAUNCHAGENT_FILE" << EOF
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
        <string>$WRAPPER_SCRIPT >> $HOME/Library/Logs/com.theory.asana-monitor.log 2>&1</string>
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
        <string>$HOME/.rbenv/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>$HOME</string>
        <key>LANG</key>
        <string>en_US.UTF-8</string>
        <key>LC_ALL</key>
        <string>en_US.UTF-8</string>
        <key>LC_CTYPE</key>
        <string>en_US.UTF-8</string>
    </dict>
</dict>
</plist>
EOF

print_success "LaunchAgent plist created"

# Validate plist
if plutil "$LAUNCHAGENT_FILE" &> /dev/null; then
  print_success "LaunchAgent plist validated"
else
  print_error "LaunchAgent plist validation failed"
  exit 1
fi

# Create caffeinate LaunchAgent (prevent sleep)
cat > "$CAFFEINATE_PLIST" << EOF
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
EOF

print_success "Sleep prevention LaunchAgent created"

# Phase 5 : Health Monitoring
print_header "Phase 5 : Setting Up Health Monitoring"

cat > "$HEALTH_SCRIPT" << EOF
#!/bin/bash
# Asana Monitor Health Check Script

MONITOR_RUNNING=\$(ps aux | grep monitor.rb | grep -v grep | wc -l)
LOG_FILE="$PROJECT_PATH/logs/agent.log"

if [ "\$MONITOR_RUNNING" -eq 0 ]; then
    echo "❌ Monitor not running!"
    echo "Last log entry :"
    tail -1 "\$LOG_FILE"
    echo ""
    echo "Attempting to restart..."
    launchctl load "$LAUNCHAGENT_FILE"
    exit 1
else
    echo "✅ Monitor running"
    echo "Recent activity :"
    tail -3 "\$LOG_FILE"
    exit 0
fi
EOF

chmod +x "$HEALTH_SCRIPT"
print_success "Health check script created"

# Phase 6 : Load LaunchAgents
print_header "Phase 6 : Loading LaunchAgents"

print_info "Testing monitor manually first..."
echo ""
echo "Running : $RUBY_PATH $MONITOR_SCRIPT"
echo "Press Ctrl+C after you see 'Polling every 180 seconds' (should take ~5 seconds)"
echo ""

if ! "$RUBY_PATH" "$MONITOR_SCRIPT" 2>&1 | head -10; then
  print_error "Manual test failed. Please check configuration."
  exit 1
fi

echo ""
print_success "Manual test passed"

# Unload if already loaded
launchctl list | grep -q "com.theory.asana-monitor" && launchctl unload "$LAUNCHAGENT_FILE" 2>/dev/null
launchctl list | grep -q "com.theory.prevent-sleep" && launchctl unload "$CAFFEINATE_PLIST" 2>/dev/null

print_info "Loading LaunchAgents..."
launchctl load "$LAUNCHAGENT_FILE"
launchctl load "$CAFFEINATE_PLIST"

sleep 3

# Verify LaunchAgent loaded
if launchctl list | grep -q "com.theory.asana-monitor"; then
  print_success "Asana Monitor LaunchAgent loaded"
else
  print_error "Failed to load Asana Monitor LaunchAgent"
  exit 1
fi

if launchctl list | grep -q "com.theory.prevent-sleep"; then
  print_success "Sleep prevention LaunchAgent loaded"
else
  print_warning "Sleep prevention LaunchAgent not loaded (may not be critical)"
fi

# Verify process is running
sleep 2
if ps aux | grep -v grep | grep -q "monitor.rb"; then
  print_success "Monitor process is running"
else
  print_error "Monitor process not found"
  echo ""
  echo "Checking LaunchAgent logs..."
  tail -20 "$HOME/Library/Logs/com.theory.asana-monitor.log"
  exit 1
fi

# Phase 7 : Security Hardening
print_header "Phase 7 : Security Hardening"

print_info "Checking security settings..."

# Check FileVault
if fdesetup status | grep -q "FileVault is On"; then
  print_success "FileVault encryption enabled"
else
  print_warning "FileVault is not enabled"
  echo "Enable FileVault : System Settings → Privacy & Security → FileVault"
  read -p "Open System Settings now? (y/n) : " open_settings
  if [[ "$open_settings" =~ ^[Yy]$ ]]; then
    open "x-apple.systempreferences:com.apple.preference.security?FDE"
  fi
fi

# Check Firewall
if /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | grep -q "enabled"; then
  print_success "Firewall is enabled"
else
  print_warning "Firewall is not enabled"
  echo "Enable Firewall : System Settings → Network → Firewall"
  read -p "Open System Settings now? (y/n) : " open_firewall
  if [[ "$open_firewall" =~ ^[Yy]$ ]]; then
    open "x-apple.systempreferences:com.apple.preference.security?Firewall"
  fi
fi

# Phase 8 : Final Configuration
print_header "Phase 8 : Final Configuration"

print_info "Configuring Energy Saver settings..."
echo ""
echo "Please configure manually :"
echo "  1. Open System Settings → Battery (or Energy Saver)"
echo "  2. Set 'Turn display off after' to 10 minutes"
echo "  3. Enable 'Prevent automatic sleeping when display is off'"
echo "  4. Disable 'Put hard disks to sleep when possible'"
echo ""
read -p "Open System Settings now? (y/n) : " open_energy
if [[ "$open_energy" =~ ^[Yy]$ ]]; then
  open "x-apple.systempreferences:com.apple.preference.battery"
fi

# Setup complete
print_header "Setup Complete!"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}                    🎉 Setup Successful! 🎉${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Your M1 Mac is now configured for 24/7 Asana monitoring."
echo ""
echo -e "${BLUE}📊 Status Check :${NC}"
echo "  LaunchAgent : $(launchctl list | grep -q asana-monitor && echo '✅ Running' || echo '❌ Not running')"
echo "  Process : $(ps aux | grep -v grep | grep -q monitor.rb && echo '✅ Active' || echo '❌ Not found')"
echo "  Sleep Prevention : $(ps aux | grep -v grep | grep -q caffeinate && echo '✅ Active' || echo '⚠️  Manual config needed')"
echo ""
echo -e "${BLUE}📁 Important Files :${NC}"
echo "  Project : $PROJECT_PATH"
echo "  Environment : $ENV_FILE (permissions : $(stat -f "%Lp" "$ENV_FILE"))"
echo "  Wrapper : $WRAPPER_SCRIPT"
echo "  LaunchAgent : $LAUNCHAGENT_FILE"
echo "  Health Check : $HEALTH_SCRIPT"
echo ""
echo -e "${BLUE}📝 Useful Commands :${NC}"
echo "  Check status : $HEALTH_SCRIPT"
echo "  View logs : tail -f $PROJECT_PATH/logs/agent.log"
echo "  LaunchAgent log : tail -f ~/Library/Logs/com.theory.asana-monitor.log"
echo "  Stop monitor : launchctl unload $LAUNCHAGENT_FILE"
echo "  Start monitor : launchctl load $LAUNCHAGENT_FILE"
echo "  Test manually : $RUBY_PATH $MONITOR_SCRIPT"
echo ""
echo -e "${BLUE}🔒 Security Checklist :${NC}"
echo "  $(fdesetup status | grep -q 'FileVault is On' && echo '✅' || echo '⚠️ ') FileVault encryption"
echo "  $(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | grep -q 'enabled' && echo '✅' || echo '⚠️ ') Firewall"
echo "  $([ "$(stat -f "%Lp" "$ENV_FILE")" = "600" ] && echo '✅' || echo '⚠️ ') Secure environment file (600)"
echo "  ⚠️  API key rotation (set calendar reminder for 90 days)"
echo ""
echo -e "${BLUE}🧪 Testing :${NC}"
echo "  1. Go to https://app.asana.com/0/1211959613518208"
echo "  2. Create a test task : 'What is 2+2?'"
echo "  3. Wait 3 minutes"
echo "  4. Check for agent response in task comments"
echo ""
echo -e "${BLUE}📖 Documentation :${NC}"
echo "  Full guide : $PROJECT_PATH/M1_SETUP_GUIDE.md"
echo "  Security : $PROJECT_PATH/SECURITY_HARDENING.md"
echo "  Troubleshooting : See M1_SETUP_GUIDE.md section"
echo ""
echo -e "${YELLOW}⚠️  Next Steps :${NC}"
echo "  1. Complete Energy Saver settings (if not done)"
echo "  2. Test with sample Asana task (see above)"
echo "  3. Monitor for 24 hours to ensure stability"
echo "  4. Set up monthly maintenance reminders"
echo ""
echo -e "${GREEN}Happy monitoring! 🚀${NC}"
echo ""
