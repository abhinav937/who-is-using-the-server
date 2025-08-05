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

1. **Run the installation:**
   ```bash
   install_api_monitor.bat
   ```

2. **Test the monitor:**
   ```bash
   run_api_monitor.bat
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
├── api_monitor.ps1       # Local monitor script (sends heartbeats only)
├── run_api_monitor.bat   # Run script
├── install_api_monitor.bat # Install script
├── config.env            # Local configuration
└── DEPLOYMENT.md         # This guide
``` 