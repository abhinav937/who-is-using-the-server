# Test Session Monitor - RDP-Only Approach (No Admin Required)
# This script detects active users using ONLY RDP session queries - NO HEARTBEATS
# Uses qwinsta.exe to check for active RDP/console sessions and sends login/logout only
#
# To run persistently:
# 1. .\run_test_monitor.ps1 -InstallStartup  # Auto-start on login
# 2. .\run_test_monitor.ps1 -Background      # Run in background now
# 3. Add start_monitor.bat to your Startup folder

param(
    [string]$ApiUrl = "https://who-is-using-the-server.vercel.app/api",
    [int]$CheckInterval = 20,  # Check every 20 seconds instead of continuous
    [int]$RequestTimeoutSec = 15
)

Write-Host "Test Session Monitor - Alternative Approach" -ForegroundColor Cyan
Write-Host "API URL: $ApiUrl" -ForegroundColor Yellow
Write-Host "Check Interval: $CheckInterval seconds" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop" -ForegroundColor Green
Write-Host ""

# Load configuration
$configPath = Join-Path $PSScriptRoot "config.env"
if (Test-Path $configPath) {
    Get-Content $configPath | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Global
        }
    }
}

# Use config values if available
if ($API_URL) { $ApiUrl = $API_URL }

# Global variables
$script:LastDetectedUsers = @()
$script:ServerId = $env:COMPUTERNAME

function Get-ChicagoTime {
    try {
        $chicagoZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Central Standard Time")
        $utcNow = [System.DateTime]::UtcNow
        $chicagoTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($utcNow, $chicagoZone)
        return $chicagoTime.ToString("yyyy-MM-dd HH:mm:ss")
    } catch {
        return Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

function Get-ActiveUsersViaWMI {
    $users = @()
    try {
        # Get logged in users via WMI (works without admin)
        $wmiUsers = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop |
            Select-Object -ExpandProperty UserName
        if ($wmiUsers) {
            $users += $wmiUsers
            Write-Host "  [WMI] Found user: $wmiUsers" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [WMI] Failed (may need admin): $($_.Exception.Message)" -ForegroundColor Gray
    }
    return $users
}

function Get-ActiveUsersViaProcesses {
    $users = @()
    try {
        # Check for explorer.exe processes (indicates GUI login)
        $explorerProcesses = Get-Process -Name explorer -IncludeUserName -ErrorAction Stop
        foreach ($process in $explorerProcesses) {
            if ($process.UserName -and $process.UserName -notmatch '^NT AUTHORITY\\|^SYSTEM$|^LOCAL SERVICE$|^NETWORK SERVICE$') {
                $users += $process.UserName
                Write-Host "  [Process] Found user: $($process.UserName)" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Warning "Process check failed: $_"
    }
    return $users
}

function Get-ActiveUsersViaRDP {
    $users = @()
    try {
        # Check RDP sessions
        $rdpOutput = qwinsta.exe 2>$null
        if ($LASTEXITCODE -eq 0) {
            $activeSessions = $rdpOutput | Select-String "Active|Conn" | Where-Object {
                $_ -match '\s+(\w+)\s+\d+\s+(Active|Conn)'
            } | ForEach-Object {
                $matches = [regex]::Match($_.Line, '\s+(\w+)\s+\d+\s+(Active|Conn)')
                if ($matches.Success -and $matches.Groups[1].Value -ne '') {
                    $user = $matches.Groups[1].Value
                    # Map "console" to actual username if it's the same person
                    if ($user -eq "console") {
                        $user = $env:USERNAME  # Use current logged-in username
                        Write-Host "  [RDP] Console session mapped to user: $user" -ForegroundColor Gray
                    } else {
                        Write-Host "  [RDP] Found RDP user: $user" -ForegroundColor Gray
                    }
                    $user
                }
            }
            $users += $activeSessions
        }
    } catch {
        Write-Host "  [RDP] Failed: $($_.Exception.Message)" -ForegroundColor Gray
    }
    return $users | Select-Object -Unique  # Remove duplicates
}

function Get-ActiveUsersViaEnvironment {
    $users = @()
    try {
        # Check current user environment variables
        $currentUser = $env:USERNAME
        if ($currentUser -and $currentUser -notmatch '^SYSTEM$|^LOCAL SERVICE$|^NETWORK SERVICE$') {
            $users += $currentUser
            Write-Host "  [Environment] Current user: $currentUser" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [Environment] Failed: $($_.Exception.Message)" -ForegroundColor Gray
    }
    return $users
}

function Get-ActiveUsers {
    Write-Host "Detecting active users via RDP sessions..." -ForegroundColor Yellow

    # Use ONLY RDP session detection (qwinsta.exe)
    $rdpUsers = Get-ActiveUsersViaRDP

    Write-Host "  Total unique active users detected: $($rdpUsers.Count)" -ForegroundColor Green
    return $rdpUsers
}

function Send-LoginNotification {
    param([string]$username)

    try {
        $loginData = @{
            action = "login"
            serverId = $script:ServerId
            username = $username
        }

        $jsonData = $loginData | ConvertTo-Json -Compress

        $response = Invoke-RestMethod -Uri $ApiUrl -Method POST -Body $jsonData -ContentType "application/json" -TimeoutSec $RequestTimeoutSec

        $timestamp = Get-ChicagoTime
        Write-Host "[$timestamp] Login sent: $username on $script:ServerId" -ForegroundColor Green

        if ($response.success) {
            Write-Host "  [OK] Login successful" -ForegroundColor Green
        }

    } catch {
        $timestamp = Get-ChicagoTime
        Write-Host "[$timestamp] [ERROR] Login failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Removed Send-HeartbeatNotification function - this approach doesn't use heartbeats
function Send-LogoutNotification {
    param([string]$username)

    try {
        $logoutData = @{
            action = "logout"
            serverId = $script:ServerId
            username = $username
            reason = "session_ended"
        }

        $jsonData = $logoutData | ConvertTo-Json -Compress

        $response = Invoke-RestMethod -Uri $ApiUrl -Method POST -Body $jsonData -ContentType "application/json" -TimeoutSec $RequestTimeoutSec

        $timestamp = Get-ChicagoTime
        Write-Host "[$timestamp] Logout sent: $username on $script:ServerId" -ForegroundColor Yellow

        if ($response.success) {
            Write-Host "  [OK] Logout processed" -ForegroundColor Green
        }

    } catch {
        $timestamp = Get-ChicagoTime
        Write-Host "[$timestamp] [ERROR] Logout failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main monitoring loop
try {
    Write-Host "Starting alternative session monitoring..." -ForegroundColor Green
    Write-Host "Checking for active users every $CheckInterval seconds" -ForegroundColor Cyan
    Write-Host ""

    while ($true) {
        try {
            $currentUsers = Get-ActiveUsers

            # Check for new logins
            $newUsers = $currentUsers | Where-Object { $_ -notin $script:LastDetectedUsers }
            foreach ($user in $newUsers) {
                Write-Host "NEW USER DETECTED: $user" -ForegroundColor Green
                Send-LoginNotification -username $user
            }

            # No heartbeats - we rely on login/logout detection only

            # Check for logouts
            $loggedOutUsers = $script:LastDetectedUsers | Where-Object { $_ -notin $currentUsers }
            foreach ($user in $loggedOutUsers) {
                Write-Host "USER LOGGED OUT: $user" -ForegroundColor Yellow
                Send-LogoutNotification -username $user
            }

            # Update last detected users
            $script:LastDetectedUsers = $currentUsers

            # Wait before next check
            Write-Host "Waiting $CheckInterval seconds before next check..." -ForegroundColor Gray
            Start-Sleep -Seconds $CheckInterval

        } catch {
            $timestamp = Get-ChicagoTime
            Write-Host "[$timestamp] [ERROR] Main loop error: $($_.Exception.Message)" -ForegroundColor Red
            Start-Sleep -Seconds $CheckInterval
        }
    }

} catch {
    Write-Host "Critical error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Write-Host "Test Session Monitor stopped." -ForegroundColor Cyan
}

<#
How to run this script as a background process without admin privileges:

1. PowerShell Background Job (Simplest):
   Start-Job -ScriptBlock { & "C:\path\to\test_session_monitor.ps1" }

2. Minimized Window:
   powershell.exe -WindowStyle Minimized -Command "& 'C:\path\to\test_session_monitor.ps1'"

3. User-Level Scheduled Task (if you can create tasks):
   - Open Task Scheduler (search for it in Start menu)
   - Create new task for your user account (not admin)
   - Action: Start a program
   - Program: powershell.exe
   - Arguments: -ExecutionPolicy Bypass -File "C:\path\to\test_session_monitor.ps1"
   - Triggers: At log on, or daily with repetition

4. Check running background jobs:
   Get-Job

5. Stop background jobs:
   Get-Job | Stop-Job
#>
