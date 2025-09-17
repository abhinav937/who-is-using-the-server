# Server Monitor - User-Level Session Management
# Handles login, logout, and heartbeat for non-admin users

param(
    [string]$ApiUrl = "https://who-is-using-the-server.vercel.app/api",
    [int]$Interval = 20,
    [string]$Mode = "auto",  # auto, login-only, heartbeat-only
    [int]$MaxRetries = 10,
    [int]$RequestTimeoutSec = 15
)

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
if ($HEARTBEAT_INTERVAL) { $Interval = [int]$HEARTBEAT_INTERVAL }
if ($MONITOR_MODE) { $Mode = $MONITOR_MODE }
if ($MAX_RETRIES) { $MaxRetries = [int]$MAX_RETRIES }
if ($REQUEST_TIMEOUT_SEC) { $RequestTimeoutSec = [int]$REQUEST_TIMEOUT_SEC }

Write-Host "Server Monitor - User-Level Session Management" -ForegroundColor Cyan
Write-Host "API URL: $ApiUrl" -ForegroundColor Yellow
Write-Host "Interval: $Interval seconds" -ForegroundColor Yellow
Write-Host "Mode: $Mode" -ForegroundColor Yellow
Write-Host "MaxRetries: $MaxRetries, RequestTimeoutSec: $RequestTimeoutSec" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop gracefully" -ForegroundColor Green
Write-Host ""

# Global variables
$script:SessionId = $null
$script:IsLoggedIn = $false
$script:LastHeartbeat = 0
$script:RetryCount = 0
# MaxRetries is now configurable via param
$script:HeartbeatCount = 0

# Removed Get-SystemInfo function - no system resource monitoring needed

function Get-ChicagoTime {
    try {
        # Get Chicago time using .NET
        $chicagoZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Central Standard Time")
        $utcNow = [System.DateTime]::UtcNow
        $chicagoTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($utcNow, $chicagoZone)
        return $chicagoTime.ToString("yyyy-MM-dd HH:mm:ss")
    } catch {
        # Fallback to local time if Chicago timezone not available
        return Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

function Send-Login {
    try {
        $username = $env:USERNAME
        $computerName = $env:COMPUTERNAME
        
        # Generate session ID if not exists
        if (-not $script:SessionId) {
            $script:SessionId = "session_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$([System.Guid]::NewGuid().ToString('N')[0..7] -join '')"
        }
        
        $loginData = @{
            action = "login"
            serverId = $computerName
            username = $username
            sessionId = $script:SessionId
        }
        
        $jsonData = $loginData | ConvertTo-Json -Compress
        
        $response = Invoke-RestMethod -Uri $ApiUrl -Method POST -Body $jsonData -ContentType "application/json" -TimeoutSec $RequestTimeoutSec
        
        $timestamp = Get-ChicagoTime
        Write-Host "[$timestamp] Login sent: $username on $computerName" -ForegroundColor Green
        
        if ($response.success) {
            $script:IsLoggedIn = $true
            $script:SessionId = $response.sessionId
            Write-Host "  [OK] Login successful (Session: $($script:SessionId))" -ForegroundColor Green
            $script:RetryCount = 0
        }
        
    } catch {
        $timestamp = Get-ChicagoTime
        Write-Host "[$timestamp] [ERROR] Login failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:RetryCount++
        
        if ($script:RetryCount -ge $MaxRetries) {
            Write-Host "  [WARN] Max retries reached for login, will keep trying in background..." -ForegroundColor Yellow
            Start-Sleep -Seconds ([Math]::Min(60, [Math]::Pow(2, [Math]::Min($script:RetryCount, 6))))
            $script:RetryCount = 0
        } else {
            $delay = [int][Math]::Min(30, [Math]::Pow(2, $script:RetryCount))
            Start-Sleep -Seconds $delay
        }
    }
}

function Send-Logout {
    try {
        if (-not $script:IsLoggedIn) {
            Write-Host "Not logged in, skipping logout" -ForegroundColor Yellow
            return
        }
        
        $username = $env:USERNAME
        $computerName = $env:COMPUTERNAME
        
        $logoutData = @{
            action = "logout"
            serverId = $computerName
            username = $username
            sessionId = $script:SessionId
            reason = "graceful_shutdown"
        }
        
        $jsonData = $logoutData | ConvertTo-Json -Compress
        
        $response = Invoke-RestMethod -Uri $ApiUrl -Method POST -Body $jsonData -ContentType "application/json" -TimeoutSec $RequestTimeoutSec
        
        $timestamp = Get-ChicagoTime
        Write-Host "[$timestamp] Logout sent: $username on $computerName" -ForegroundColor Yellow
        
        if ($response.success) {
            Write-Host "  [OK] Logout processed: $($response.message)" -ForegroundColor Green
            if ($response.serverFree) {
                Write-Host "  [INFO] Server is now free" -ForegroundColor Cyan
            }
            $script:IsLoggedIn = $false
        }
        
    } catch {
        $timestamp = Get-ChicagoTime
        Write-Host "[$timestamp] [ERROR] Logout failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Send-Heartbeat {
    try {
        $username = $env:USERNAME
        $computerName = $env:COMPUTERNAME
        # Removed system info collection
        
        $heartbeatData = @{
            action = "heartbeat"
            serverId = $computerName
            username = $username
            sessionId = $script:SessionId
            # Removed CPU and memory data collection
            status = "active"
            timestamp = [long]([DateTimeOffset]::Now.ToUnixTimeSeconds())
        }
        
        $jsonData = $heartbeatData | ConvertTo-Json -Compress
        
        $response = Invoke-RestMethod -Uri $ApiUrl -Method POST -Body $jsonData -ContentType "application/json" -TimeoutSec $RequestTimeoutSec
        
        if ($response.success) {
            $script:LastHeartbeat = Get-Date
            $script:RetryCount = 0
            $script:HeartbeatCount++
            if (($script:HeartbeatCount % 10) -eq 0) {
                $timestamp = Get-ChicagoTime
                Write-Host "[$timestamp] Heartbeats sent so far: $($script:HeartbeatCount)" -ForegroundColor Cyan
            }
        } else {
            # Treat non-success responses as transient and retry with backoff
            $script:RetryCount++
            $delay = [int][Math]::Min(60, [Math]::Pow(2, $script:RetryCount))
            Write-Host "  [INFO] Heartbeat non-success, retry #$($script:RetryCount) in $delay seconds" -ForegroundColor Yellow
            Start-Sleep -Seconds $delay
        }
        
    } catch {
        $timestamp = Get-ChicagoTime
        Write-Host "[$timestamp] [ERROR] Heartbeat failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:RetryCount++
        $delay = [int][Math]::Min(60, [Math]::Pow(2, $script:RetryCount))
        Write-Host "  [INFO] Retry #$($script:RetryCount) in $delay seconds" -ForegroundColor Yellow
        Start-Sleep -Seconds $delay
    }
}

# Simple cleanup handler (no admin required)
$script:CleanupPerformed = $false

function Invoke-Cleanup {
    if (-not $script:CleanupPerformed -and $script:IsLoggedIn) {
        $script:CleanupPerformed = $true
        Write-Host "`nPerforming cleanup, sending logout..." -ForegroundColor Yellow
        Send-Logout
        Write-Host "Cleanup completed." -ForegroundColor Cyan
    }
}

# Main execution
try {
    # Initial login
    if ($Mode -eq "auto" -or $Mode -eq "login-only") {
        Write-Host "Performing initial login..." -ForegroundColor Cyan
        Send-Login
        
        if (-not $script:IsLoggedIn) {
            Write-Host "Login not yet successful, continuing and will retry with backoff..." -ForegroundColor Yellow
        }
    }
    
    # Main loop
    Write-Host "Starting monitoring loop..." -ForegroundColor Green
    Write-Host ""
    
    while ($true) {
        try {
            if ($Mode -eq "auto" -or $Mode -eq "heartbeat-only") {
                Send-Heartbeat
            }
            
            # Note: Logout checks are now handled by external service (GitHub Actions)
            # This ensures detection works even when terminal is closed abruptly
            
            # Wait for next interval
            Start-Sleep -Seconds $Interval
            
        } catch {
            $timestamp = Get-ChicagoTime
            Write-Host "[$timestamp] [ERROR] Main loop error: $($_.Exception.Message)" -ForegroundColor Red
            
            # Do not force logout or exit on transient loop errors
            $script:RetryCount++
            $delay = [int][Math]::Min(60, [Math]::Pow(2, $script:RetryCount))
            Write-Host "  [INFO] Loop error, retry #$($script:RetryCount) in $delay seconds" -ForegroundColor Yellow
            Start-Sleep -Seconds $delay
        }
    }
    
} catch {
    Write-Host "Critical error: $($_.Exception.Message)" -ForegroundColor Red
    
    # Ensure logout is sent even on critical errors
    if ($script:IsLoggedIn) {
        Send-Logout
    }
    
} finally {
    # Final cleanup
    Invoke-Cleanup
    Write-Host "Server Monitor cleanup completed." -ForegroundColor Cyan
} 