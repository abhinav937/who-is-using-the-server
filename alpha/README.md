# Alpha Test Scripts

This folder contains experimental/test scripts for alternative session monitoring approaches.

## Scripts Overview

### `test_session_monitor.ps1`
**Main test script** - RDP-only session monitoring approach that:
- Detects active users via RDP sessions only (qwinsta.exe)
- Sends login/logout notifications + silent keep-alive messages
- Keep-alive prevents session expiration (sessions expire after 3 minutes if not refreshed)
- Works without administrator privileges
- Maps "console" sessions to actual usernames (prevents duplicate reporting)
- Checks every 20 seconds instead of continuous monitoring

### `run_test_monitor.ps1`
**Launcher script** - Easy way to run the test monitor with different options:
```powershell
# Test normally
.\run_test_monitor.ps1

# Run in background
.\run_test_monitor.ps1 -Background

# Install to startup (auto-start on login)
.\run_test_monitor.ps1 -InstallStartup

# Stop background jobs
.\run_test_monitor.ps1 -Stop
```

### `start_monitor.bat`
**Simple batch file** - Basic launcher for Windows startup folder.

## Usage

1. **Test the approach:**
   ```powershell
   .\run_test_monitor.ps1
   ```

2. **Make it persistent:**
   ```powershell
   .\run_test_monitor.ps1 -InstallStartup
   ```

3. **Check dashboard** - Script updates the same HTML dashboard as the main system.

## Key Differences from Main System

| Feature | Main System (`api_monitor.ps1`) | Test System (`test_session_monitor.ps1`) |
|---------|---------------------------------|-----------------------------------------|
| **Execution** | Continuous monitoring | Periodic checks (every 20s) |
| **Admin Required** | No | No |
| **Resource Usage** | High (always running) | Low (checks only) |
| **Detection Method** | Heartbeat-based | RDP sessions only (qwinsta.exe) |
| **Heartbeat Usage** | Yes (continuous) | Silent keep-alive (every 20s) |
| **Persistence** | Manual startup | Can auto-start on login |

## Status: Experimental
These scripts are experimental alternatives to the main monitoring system. They provide the same functionality with potentially lower resource usage and different detection methods.
