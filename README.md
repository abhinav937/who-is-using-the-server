# Server Monitor API

A comprehensive server monitoring system that tracks user sessions, sends notifications, and provides real-time status monitoring through a Vercel-hosted API with Redis storage.

## Overview

This system monitors server usage by tracking user sessions through heartbeat signals. It automatically detects when users log in/out and sends notifications to Microsoft Teams. The system consists of:

- **Vercel API**: Serverless API endpoints for session management
- **Redis Storage**: Persistent session data storage
- **PowerShell Scripts**: Client-side monitoring and automation
- **Batch Scripts**: Windows installation and management utilities

## Features

- **Real-time Session Tracking**: Monitor who's using the server
- **Automatic Logout Detection**: Detect abrupt disconnections after 30 seconds
- **Teams Notifications**: Send login/logout alerts to Microsoft Teams
- **Heartbeat Monitoring**: Continuous session validation
- **System Tray Integration**: Runs hidden with tray icon for status/control
- **Hassle-free Installation**: One-click setup with auto-start on login
- **No Admin Required**: Works with standard user privileges
- **Elegant Management**: Single script handles install/uninstall/status
- **Survives Logoff**: Monitor persists through Windows logoff/restart
- **Cross-platform API**: Works with any system that can make HTTP requests

## Setup Instructions

### Prerequisites

- **Node.js** (v14 or higher)
- **Vercel CLI**: `npm install -g vercel`
- **Redis Database** (Vercel KV recommended)
- **Microsoft Teams Webhook** (optional, for notifications)

### 1. API Deployment

1. **Clone and prepare the project:**
   ```bash
   git clone <your-repo-url>
   cd server-monitor-api
   npm install
   ```

2. **Deploy to Vercel:**
   ```bash
   vercel login
   vercel --prod
   ```

3. **Set up Vercel KV Database:**
   ```bash
   vercel kv create
   ```
   - Choose a name (e.g., `server-monitor-kv`)
   - Select your preferred region
   - Link to your project: `vercel kv pull`

4. **Configure Environment Variables in Vercel Dashboard:**
   - `KV_REST_API_URL`: Your KV database REST API URL
   - `KV_REST_API_TOKEN`: Your KV database REST API token
   - `TEAMS_WEBHOOK_URL`: Your Microsoft Teams webhook URL (optional)
   - `SERVER_NAME`: Display name for your server (optional)

### 2. Client Setup (Windows)

1. **Download the monitoring scripts** to your local machine

2. **Configure settings** in `config.env` (optional):
   ```env
   API_URL=https://your-app.vercel.app/api
   HEARTBEAT_INTERVAL=30
   ```

3. **Run the elegant installer:**
   ```batch
   # Install and start monitoring
   .\install.bat

   # Or use PowerShell directly for more options
   .\setup.ps1 -Install -ApiUrl "https://your-app.vercel.app/api" -CheckInterval 20
   ```

4. **The installer will:**
   - Install the monitor to auto-start on login (runs hidden)
   - Create a system tray icon for status/control
   - Set up automatic login/heartbeat/logout notifications
   - No admin privileges required!

## Usage

### Automatic Monitoring

Once installed, the system automatically:
- Starts monitoring when you log into Windows
- Sends login notification to Teams
- Sends heartbeat signals every 30 seconds
- Detects and reports logouts/disconnections

### Manual Control

Use the elegant setup script for all operations:

```powershell
# Install and start monitoring
.\setup.ps1 -Install

# Start monitor manually (without installing)
.\setup.ps1 -Start

# Stop monitor
.\setup.ps1 -Stop

# Check status
.\setup.ps1 -Status

# Uninstall everything
.\setup.ps1 -Uninstall

# Custom installation
.\setup.ps1 -Install -ApiUrl "https://your-api.vercel.app/api" -CheckInterval 20
```

### Batch Script Options

```batch
# Quick install
install.bat

# Quick uninstall
uninstall.bat

# Manual start
run_monitor.bat
```

## API Endpoints

### POST /api

**Actions supported:**
- `login`: Register a new user session
- `logout`: End a user session
- `heartbeat`: Update session timestamp
- `check_logouts`: Check for timed-out sessions

**Request format:**
```json
{
  "action": "login",
  "username": "john.doe",
  "computer": "DESKTOP-ABC123",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### GET /api

- **Status Check**: `GET /api` - Returns current active sessions
- **Test Teams**: `GET /api?test=teams` - Test Teams webhook
- **Check Logouts**: `GET /api?action=check_logouts` - Manual logout check

## Project Structure

```
server-monitor-api/
├── api/
│   └── index.js              # Main Vercel API handler
├── api_monitor.ps1           # Advanced tray monitor (runs hidden)
├── setup.ps1                 # Elegant setup script (install/uninstall/status)
├── install.bat               # Quick install batch file
├── uninstall.bat             # Quick uninstall batch file
├── run_monitor.bat           # Manual start batch file
├── config.env                # Configuration file
├── dashboard.html            # Web dashboard
├── dashboard.css             # Dashboard styling
├── package.json              # Node.js dependencies
├── vercel.json               # Vercel deployment config
└── README.md                 # This file
```

## Configuration

### Environment Variables

**For API (Vercel Dashboard):**
- `KV_REST_API_URL`: Redis/KV database URL
- `KV_REST_API_TOKEN`: Database authentication token
- `TEAMS_WEBHOOK_URL`: Microsoft Teams notification webhook
- `SERVER_NAME`: Display name for notifications

**For Client (config.env):**
- `API_URL`: Your deployed API endpoint
- `HEARTBEAT_INTERVAL`: Seconds between heartbeats (default: 30)
- `LOG_FILE`: Local log file name
- `MONITOR_MODE`: Monitoring mode (auto/login-only/heartbeat-only)

### Teams Webhook Setup

1. In Microsoft Teams, go to your channel
2. Click "..." → "Connectors" → "Incoming Webhook"
3. Create a new webhook and copy the URL
4. Add the URL to your Vercel environment variables as `TEAMS_WEBHOOK_URL`

## Monitoring & Logs

- **API Logs**: View in Vercel Dashboard → Functions tab
- **Client Logs**: Check `api_monitor.log` in the script directory
- **Session Data**: Stored in Redis/Vercel KV with automatic expiration

## Troubleshooting

### Common Issues

1. **"Access Denied" during installation:**
   - Right-click PowerShell/Command Prompt → "Run as Administrator"
   - Or use the batch files which don't require admin rights

2. **API not responding:**
   - Check your Vercel deployment status
   - Verify environment variables are set correctly
   - Test the API endpoint directly in a browser

3. **Teams notifications not working:**
   - Verify webhook URL is correct
   - Test with: `GET /api?test=teams`
   - Check Teams channel permissions

4. **Sessions not being tracked:**
   - Verify Redis/KV database is connected
   - Check API logs in Vercel dashboard
   - Ensure heartbeat interval isn't too long

### Manual Testing

Test your setup with curl or PowerShell:

```bash
# Test API status
curl https://your-app.vercel.app/api

# Test login
curl -X POST https://your-app.vercel.app/api \
  -H "Content-Type: application/json" \
  -d '{"action":"login","username":"test","computer":"TEST-PC"}'
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source and available under the [MIT License](LICENSE).

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review API logs in Vercel dashboard
3. Check local log files for client-side issues
4. Create an issue in the repository

---

**Note**: This system is designed for internal server monitoring. Ensure you comply with your organization's monitoring and privacy policies.