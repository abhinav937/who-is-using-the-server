# GitHub Actions Logout Checker Setup

## Overview
This GitHub Actions workflow automatically checks for timed-out sessions every minute, ensuring that abrupt terminal closures are detected even when the PowerShell script is terminated.

## How It Works

### 1. **Automatic Scheduling**
- Runs every minute via GitHub Actions cron schedule
- Calls the API endpoint: `https://who-is-using-the-server.vercel.app/api?action=check_logouts`
- Works independently of your local PowerShell script

### 2. **Detection Process**
- **30-second timeout**: Sessions are considered timed out after 30 seconds of no heartbeat
- **90-second expiry**: Redis automatically expires sessions after 90 seconds
- **External monitoring**: GitHub Actions ensures detection even when terminal is closed

### 3. **Notification Flow**
1. User abruptly closes terminal
2. No more heartbeats sent to API
3. After 30 seconds: GitHub Actions detects timeout
4. Logout notification sent to Teams
5. Server free notification sent (if applicable)

## Setup Instructions

### 1. **Enable GitHub Actions**
- Push this repository to GitHub
- Go to Settings → Actions → General
- Enable "Allow all actions and reusable workflows"

### 2. **Verify Workflow**
- Go to Actions tab in your GitHub repository
- You should see "Logout Checker" workflow
- It will start running automatically every minute

### 3. **Manual Testing**
- Go to Actions → Logout Checker → Run workflow
- This allows you to manually trigger a logout check

## Monitoring

### Check Workflow Status
```bash
# View recent runs
gh run list --workflow="Logout Checker"
```

### View Logs
- Go to Actions → Logout Checker → Click on any run
- Check the "Check for logouts" step logs

## Benefits

✅ **Works when terminal is closed abruptly**
✅ **No local dependencies**
✅ **Free (GitHub Actions free tier)**
✅ **Reliable and monitored**
✅ **Automatic cleanup**

## Troubleshooting

### Workflow Not Running
- Check GitHub Actions is enabled
- Verify cron syntax: `*/1 * * * *` (every minute)
- Check repository permissions

### API Errors
- Verify your Vercel deployment is working
- Check the API endpoint is accessible
- Review Vercel function logs

### No Notifications
- Verify Teams webhook URL is configured
- Check Vercel environment variables
- Test Teams notifications manually

## Configuration

### Adjust Frequency
Edit `.github/workflows/logout-checker.yml`:
```yaml
schedule:
  # Every 30 seconds (minimum)
  - cron: '*/1 * * * *'
  # Every 2 minutes
  - cron: '*/2 * * * *'
```

### Change API Endpoint
Update the curl command in the workflow:
```bash
curl -s "YOUR_API_URL?action=check_logouts"
``` 