# Vercel API Deployment Guide

This guide will help you deploy the server monitoring API to Vercel with persistent storage.

## Prerequisites

1. **Node.js** installed on your computer
2. **Vercel CLI** installed: `npm i -g vercel`
3. **Git** for version control

## Step 1: Set Up Vercel KV Storage

1. **Install Vercel CLI:**
   ```bash
   npm i -g vercel
   ```

2. **Login to Vercel:**
   ```bash
   vercel login
   ```

3. **Create Vercel KV Database:**
   ```bash
   vercel kv create
   ```
   - Choose a name for your database (e.g., `server-monitor-kv`)
   - Select a region close to you
   - Note the connection details

4. **Link KV to your project:**
   ```bash
   vercel kv pull
   ```

## Step 2: Deploy to Vercel

1. **Deploy the API:**
   ```bash
   vercel --prod
   ```

2. **Note the deployment URL** (e.g., `https://your-app.vercel.app`)

## Step 3: Set Environment Variables

1. **Go to Vercel Dashboard:**
   - Visit https://vercel.com/dashboard
   - Select your project

2. **Add Environment Variables:**
   - Go to Settings → Environment Variables
   - Add: `TEAMS_WEBHOOK_URL`
   - Value: Your Teams webhook URL
   - Environment: Production

3. **Verify KV Environment Variables:**
   - The KV connection variables should be automatically added
   - Check that `KV_URL`, `KV_REST_API_URL`, `KV_REST_API_TOKEN`, `KV_REST_API_READ_ONLY_TOKEN` are present

## Step 4: Update Local Configuration

1. **Update API URL in config.env:**
   - Edit `config.env`
   - Replace `https://your-vercel-app.vercel.app/api` with your actual API URL

2. **Test the API:**
   ```bash
   curl -X POST https://your-app.vercel.app/api \
     -H "Content-Type: application/json" \
     -d '{"serverId":"test","username":"testuser","cpu":25,"memory":8192,"status":"active","timestamp":1234567890}'
   ```

## Step 5: Install Local Monitor

### Option 1: One-Click Install (Recommended)

**For Windows users without admin access:**

1. **Double-click `install.bat`** or run:
   ```cmd
   install.bat
   ```

2. **Or use PowerShell version:**
   ```powershell
   .\install.ps1
   ```

### Option 2: Manual Installation

1. **Run the monitor directly:**
   ```cmd
   run_monitor.bat
   ```

2. **Or run PowerShell script directly:**
   ```powershell
   .\api_monitor.ps1
   ```

### What Gets Installed

- **Startup Script**: Automatically starts monitoring on login
- **Desktop Shortcut**: "Server Monitor" shortcut for manual start
- **Configuration**: `config.env` file with default settings

### Uninstall

**One-click uninstall:**
```cmd
uninstall.bat
```

**Or PowerShell version:**
```powershell
.\uninstall.ps1
```

## How It Works

### Architecture
- **Local Script** (`api_monitor.ps1`) - Sends heartbeat data to Vercel API
- **Vercel API** (`api/index.js`) - Tracks sessions using Vercel KV storage
- **Vercel KV** - Persistent Redis storage for session data
- **Teams** - Receives notifications for login/logoff events

### API Endpoints

- **POST /api** - Send heartbeat data
- **GET /api?serverId=xxx** - Get status and detect logoffs

### Heartbeat Data Format

```json
{
  "serverId": "COMPUTERNAME",
  "username": "currentuser",
  "cpu": 25.5,
  "memory": 8192,
  "status": "active",
  "timestamp": 1234567890
}
```

### Logoff Detection

- API tracks last heartbeat time for each user in Vercel KV
- If no heartbeat for 90 seconds, user is considered logged off
- Teams notification is sent automatically by the Vercel API

### Teams Notifications

The Vercel API sends Teams notifications for:
- **Login events** - When a new user session is detected
- **Logoff events** - When a user session times out (90 seconds)
- **Server free events** - When the last user logs off

## Troubleshooting

### API Not Responding
- Check Vercel deployment status
- Verify environment variables are set
- Check Vercel function logs
- Ensure Vercel KV is properly configured

### Local Script Not Working
- Verify API URL is correct in `config.env`
- Check PowerShell execution policy
- Look at `api_monitor.log` for errors

### Teams Notifications Not Working
- Verify `TEAMS_WEBHOOK_URL` is set in Vercel dashboard
- Check webhook URL is valid
- Test webhook manually
- Check Vercel function logs for notification errors

### KV Storage Issues
- Verify KV environment variables are set
- Check KV connection in Vercel dashboard
- Ensure KV database is in the same region as your function

## Files Structure

```
├── api/
│   └── index.js          # Vercel API (uses KV storage)
├── vercel.json           # Vercel config
├── package.json          # Dependencies (includes @vercel/kv)
├── api_monitor.ps1       # Local monitor script
├── run_monitor.bat       # Run script
├── install.bat           # One-click install (batch)
├── install.ps1           # One-click install (PowerShell)
├── uninstall.bat         # One-click uninstall (batch)
├── uninstall.ps1         # One-click uninstall (PowerShell)
├── check_logouts.bat     # Manual logout check (batch)
├── check_logouts.ps1     # Manual logout check (PowerShell)
├── config.env            # Local configuration
└── DEPLOYMENT.md         # This guide
``` 