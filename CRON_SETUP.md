# Cron Setup Instructions

## Overview

The Asana Agent Monitor should run every 5 minutes via cron to automatically process tasks in the "1 - Agent Tasks" Asana project.

## Prerequisites

1. ✅ ASANA_API_KEY environment variable set
2. ✅ All Code Mode APIs available
3. ✅ Monitor script tested and working

## Cron Job Installation

### Step 1: Open crontab

```bash
crontab -e
```

### Step 2: Add cron entry

Add this line to run the monitor every 5 minutes:

```bash
*/5 * * * * cd ~/Documents/coding/asana-agent-monitor && ruby bin/monitor.rb >> logs/agent.log 2>&1
```

**Explanation:**
- `*/5 * * * *` - Every 5 minutes
- `cd ~/Documents/coding/asana-agent-monitor` - Change to project directory
- `ruby bin/monitor.rb` - Run the monitor script
- `>> logs/agent.log 2>&1` - Append stdout & stderr to log file

### Step 3: Save and exit

- In vim: Press `Esc`, then `:wq`
- In nano: Press `Ctrl+X`, then `Y`, then `Enter`

### Step 4: Verify cron job

```bash
crontab -l
```

You should see your new cron entry listed.

## Alternative: Run manually

For testing or manual runs:

```bash
cd ~/Documents/coding/asana-agent-monitor
./bin/monitor.rb
```

## Monitoring

### Check logs

```bash
# View recent activity
tail -f ~/Documents/coding/asana-agent-monitor/logs/agent.log

# View last 50 lines
tail -50 ~/Documents/coding/asana-agent-monitor/logs/agent.log

# Search logs for errors
grep ERROR ~/Documents/coding/asana-agent-monitor/logs/agent.log
```

### Expected log output

```
[2025-11-16 14:00:00] [INFO] AgentMonitor initialized (project: 1211959613518208)
[2025-11-16 14:00:00] [INFO] Starting agent monitor run...
[2025-11-16 14:00:01] [INFO] Found 3 incomplete tasks
[2025-11-16 14:00:01] [INFO] Processing task 123456: Research thehog.ai
[2025-11-16 14:00:01] [INFO]   Routing to Workflows::CompanyResearch
[2025-11-16 14:00:05] [INFO]   ✅ Workflow succeeded
[2025-11-16 14:00:06] [INFO] Agent monitor run complete
```

## Troubleshooting

### Cron not running

1. Check if cron service is running:
   ```bash
   ps aux | grep cron
   ```

2. Check system logs:
   ```bash
   grep CRON /var/log/system.log
   ```

3. Verify environment variables are available in cron:
   ```bash
   */5 * * * * env > /tmp/cron_env.txt
   ```

### Environment variables not available

Cron runs with minimal environment. If ASANA_API_KEY is not available:

**Option 1: Load from .zshrc**
```bash
*/5 * * * * source ~/.zshrc && cd ~/Documents/coding/asana-agent-monitor && ruby bin/monitor.rb >> logs/agent.log 2>&1
```

**Option 2: Set directly in crontab**
```bash
ASANA_API_KEY=your_key_here
*/5 * * * * cd ~/Documents/coding/asana-agent-monitor && ruby bin/monitor.rb >> logs/agent.log 2>&1
```

### Logs not appearing

1. Check log directory exists:
   ```bash
   ls -la ~/Documents/coding/asana-agent-monitor/logs/
   ```

2. Check write permissions:
   ```bash
   touch ~/Documents/coding/asana-agent-monitor/logs/test.log
   ```

3. Run manually to see output:
   ```bash
   cd ~/Documents/coding/asana-agent-monitor
   ./bin/monitor.rb
   ```

## Disabling Cron Job

To temporarily disable:

```bash
crontab -e
# Comment out the line with #:
# */5 * * * * cd ~/Documents/coding/asana-agent-monitor && ruby bin/monitor.rb >> logs/agent.log 2>&1
```

To permanently remove:

```bash
crontab -e
# Delete the entire line
```

## Testing Before Production

1. **Manual test:** Run `./bin/monitor.rb` and verify it works
2. **Single cron run:** Set cron to run once per hour for testing
3. **Monitor logs:** Watch logs for first few runs
4. **Create test task:** Add a simple task to "1 - Agent Tasks" project
5. **Verify processing:** Check task gets processed within 5 minutes

## Production Checklist

- [ ] Monitor script tested manually
- [ ] ASANA_API_KEY verified
- [ ] Cron entry added
- [ ] Logs directory has write permissions
- [ ] Test task processed successfully
- [ ] Error handling verified (create intentionally broken task)
- [ ] Log rotation considered (optional, for long-term)

## Next Steps

After cron is running successfully:
- Monitor logs daily for first week
- Create variety of test tasks to verify all workflows
- Adjust cron frequency if needed (e.g., every 10 minutes instead of 5)
- Consider adding alerting for failures (email on ERROR in logs)
