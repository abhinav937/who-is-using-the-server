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

# Install tray monitor to startup (auto-start + tray icon)
.\run_test_monitor.ps1 -InstallStartup

# Stop background jobs
.\run_test_monitor.ps1 -Stop
```

### `start_monitor.bat`
**Simple batch file** - Basic launcher for Windows startup folder.

### `tray_monitor.ps1`
**System tray application** - Windows Forms app that runs in the system tray:
- Survives user logoff/signout
- Auto-starts on Windows login
- Minimizes to system tray
- Click tray icon for detailed status
- Right-click menu for control

### `run_tray_monitor.ps1`
**Tray app launcher** - Easy way to run the system tray monitor:
```powershell
# Test normally
.\run_tray_monitor.ps1

# Run hidden in background
.\run_tray_monitor.ps1 -RunHidden

# Install to startup
.\run_tray_monitor.ps1 -InstallStartup
```

## Usage

1. **Test the basic approach:**
   ```powershell
   .\run_test_monitor.ps1
   ```

2. **Test the system tray app (recommended):**
   ```powershell
   .\run_tray_monitor.ps1
   ```

3. **Make it persistent (survives logoff):**
   ```powershell
   .\run_tray_monitor.ps1 -InstallStartup
   ```

4. **Check dashboard** - Both scripts update the same HTML dashboard.

## Key Differences from Main System

| Feature | Main System (`api_monitor.ps1`) | Test System (`test_session_monitor.ps1`) | Tray App (`tray_monitor.ps1`) |
|---------|---------------------------------|-----------------------------------------|-------------------------------------|
| **Execution** | Continuous monitoring | Periodic checks (every 20s) | Periodic checks (every 20s) |
| **Admin Required** | No | No | No |
| **Resource Usage** | High (always running) | Low (checks only) | Low (checks only) |
| **Detection Method** | Heartbeat-based | RDP sessions only (qwinsta.exe) | RDP sessions only (qwinsta.exe) |
| **Heartbeat Usage** | Yes (continuous) | Silent keep-alive (every 20s) | Silent keep-alive (every 20s) |
| **Persistence** | Manual startup | Can auto-start on login | **Survives logoff/signout** |
| **UI** | Console window | Console window | **System tray icon** |

## Status: Experimental
These scripts are experimental alternatives to the main monitoring system. They provide the same functionality with potentially lower resource usage and different detection methods.
