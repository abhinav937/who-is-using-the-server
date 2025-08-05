# Server Monitor - User-Level Session Management
# Handles login, logout, and heartbeat for non-admin users

param(
    [string]$ApiUrl = "https://who-is-using-the-server.vercel.app/api",
    [int]$Interval = 20,
    [string]$Mode = "auto"  # auto, login-only, heartbeat-only
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

Write-Host "Server Monitor - User-Level Session Management" -ForegroundColor Cyan
Write-Host "API URL: $ApiUrl" -ForegroundColor Yellow
Write-Host "Interval: $Interval seconds" -ForegroundColor Yellow
Write-Host "Mode: $Mode" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop gracefully" -ForegroundColor Green
Write-Host ""

# Global variables
$script:SessionId = $null
$script:IsLoggedIn = $false
$script:LastHeartbeat = 0
$script:RetryCount = 0
$script:MaxRetries = 3

function Get-SystemInfo {
    try {
        $cpu = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples[0].CookedValue
        $memory = [math]::Round((Get-Counter "\Memory\Available MBytes").CounterSamples[0].CookedValue)
        return @{
            cpu = [math]::Round($cpu, 2)
            memory = [math]::Round($memory)
        }
    } catch {
        return @{
            cpu = 0
            memory = 0
        }
    }
}

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
        
        $response = Invoke-RestMethod -Uri $ApiUrl -Method POST -Body $jsonData -ContentType "application/json" -TimeoutSec 10
        
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
        
        if ($script:RetryCount -ge $script:MaxRetries) {
            Write-Host "  [FATAL] Max retries reached, exiting..." -ForegroundColor Red
            exit 1
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
        
        $response = Invoke-RestMethod -Uri $ApiUrl -Method POST -Body $jsonData -ContentType "application/json" -TimeoutSec 10
        
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
        $systemInfo = Get-SystemInfo
        
        $heartbeatData = @{
            action = "heartbeat"
            serverId = $computerName
            username = $username
            sessionId = $script:SessionId
            cpu = $systemInfo.cpu
            memory = $systemInfo.memory
            status = "active"
            timestamp = [long]([DateTimeOffset]::Now.ToUnixTimeSeconds())
        }
        
        $jsonData = $heartbeatData | ConvertTo-Json -Compress
        
        $response = Invoke-RestMethod -Uri $ApiUrl -Method POST -Body $jsonData -ContentType "application/json" -TimeoutSec 10
        
        $timestamp = Get-ChicagoTime
        Write-Host "[$timestamp] Heartbeat: $username on $computerName (CPU: $($systemInfo.cpu)%, Memory: $($systemInfo.memory)MB)" -ForegroundColor White
        
        if ($response.success) {
            Write-Host "  [OK] API response: $($response.message) (Sessions: $($response.sessionCount))" -ForegroundColor Green
            $script:LastHeartbeat = Get-Date
            $script:RetryCount = 0
        }
        
    } catch {
        $timestamp = Get-ChicagoTime
        Write-Host "[$timestamp] [ERROR] Heartbeat failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:RetryCount++
        
        if ($script:RetryCount -ge $script:MaxRetries) {
            Write-Host "  [FATAL] Max retries reached, attempting logout..." -ForegroundColor Red
            Send-Logout
            exit 1
        }
    }
}

# Register cleanup handler for abrupt termination
$cleanupHandler = {
    if ($script:IsLoggedIn) {
        Write-Host "`nReceived termination signal, sending logout..." -ForegroundColor Yellow
        Send-Logout
        Write-Host "Cleanup completed." -ForegroundColor Cyan
    }
    exit 0
}

# Register the cleanup handler for various termination signals
Register-EngineEvent -SourceIdentifier ([System.Console]::CancelKeyPress) -Action $cleanupHandler
Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PsEngineEvent]::Exiting) -Action $cleanupHandler

# Main execution
try {
    # Initial login
    if ($Mode -eq "auto" -or $Mode -eq "login-only") {
        Write-Host "Performing initial login..." -ForegroundColor Cyan
        Send-Login
        
        if (-not $script:IsLoggedIn) {
            Write-Host "Failed to login, exiting..." -ForegroundColor Red
            exit 1
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
            
            # Wait for next interval
            Start-Sleep -Seconds $Interval
            
        } catch {
            $timestamp = Get-ChicagoTime
            Write-Host "[$timestamp] [ERROR] Main loop error: $($_.Exception.Message)" -ForegroundColor Red
            
            # Attempt logout on critical errors
            if ($script:IsLoggedIn) {
                Send-Logout
            }
            break
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
    if ($script:IsLoggedIn) {
        Send-Logout
    }
    Write-Host "Server Monitor cleanup completed." -ForegroundColor Cyan
    
    # Unregister cleanup handlers
    Unregister-Event -SourceIdentifier ([System.Console]::CancelKeyPress) -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier ([System.Management.Automation.PsEngineEvent]::Exiting) -ErrorAction SilentlyContinue
} 