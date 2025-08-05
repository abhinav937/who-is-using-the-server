# Server Monitor - Heartbeat Client
# Sends heartbeat data to Vercel API for session tracking

param(
    [string]$ApiUrl = "https://who-is-using-the-server.vercel.app/api",
    [int]$Interval = 30
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

Write-Host "Server Monitor - Heartbeat Client"
Write-Host "API URL: $ApiUrl"
Write-Host "Interval: $Interval seconds"
Write-Host "Press Ctrl+C to stop"
Write-Host ""

function Send-Heartbeat {
    try {
        # Get current user and computer info
        $username = $env:USERNAME
        $computerName = $env:COMPUTERNAME
        
        # Get system info
        $cpu = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples[0].CookedValue
        $memory = [math]::Round((Get-Counter "\Memory\Available MBytes").CounterSamples[0].CookedValue)
        
        # Create heartbeat data
        $heartbeatData = @{
            serverId = $computerName
            username = $username
            cpu = [math]::Round($cpu, 2)
            memory = [math]::Round($memory)
            status = "active"
            timestamp = [long]([DateTimeOffset]::Now.ToUnixTimeSeconds())
        }
        
        # Convert to JSON
        $jsonData = $heartbeatData | ConvertTo-Json -Compress
        
        # Send to API
        $response = Invoke-RestMethod -Uri $ApiUrl -Method POST -Body $jsonData -ContentType "application/json" -TimeoutSec 10
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] Heartbeat sent: $username on $computerName (CPU: $($heartbeatData.cpu)%, Memory: $($heartbeatData.memory)MB)"
        
        if ($response.success) {
            Write-Host "  [OK] API response: $($response.message) (Sessions: $($response.sessionCount))"
        }
        
    } catch {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [ERROR] Error sending heartbeat: $($_.Exception.Message)" -ForegroundColor Red
        
        # Log error to file if LOG_FILE is set
        if ($LOG_FILE) {
            $logPath = Join-Path $PSScriptRoot $LOG_FILE
            "$timestamp ERROR: $($_.Exception.Message)" | Out-File -FilePath $logPath -Append
        }
    }
}

# Main loop
Write-Host "Starting heartbeat loop..." -ForegroundColor Green
Write-Host ""

while ($true) {
    Send-Heartbeat
    
    # Wait for next interval
    Start-Sleep -Seconds $Interval
} 