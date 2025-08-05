# API-based Server Monitor
# Sends heartbeat data to Vercel API for better logout detection

param(
    [string]$ConfigFile = "config.env",
    [string]$LogFile = "api_monitor.log",
    [string]$ApiUrl = "",
    [string]$ServerId = $env:COMPUTERNAME,
    [int]$HeartbeatInterval = 30,
    [switch]$Test
)

# Function to read config file
function Read-Config {
    param([string]$ConfigPath)
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Config file not found: $ConfigPath"
        exit 1
    }
    
    $config = @{}
    Get-Content $ConfigPath | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $config[$key] = $value
        }
    }
    return $config
}

# Read configuration
$config = Read-Config $ConfigFile

# Override with parameters if provided
if ($ApiUrl -eq "") { $ApiUrl = $config['API_URL'] }
if ($LogFile -eq "api_monitor.log") { $LogFile = $config['LOG_FILE'] }
if ($HeartbeatInterval -eq 30) { $HeartbeatInterval = [int]$config['HEARTBEAT_INTERVAL'] }

# Create log directory if it doesn't exist
$logDir = Split-Path $LogFile -Parent
if ($logDir -and -not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Function to write to log
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $LogFile -Value $logEntry
}

# Function to get system info
function Get-SystemInfo {
    try {
        $info = @{
            username = $env:USERNAME
            cpu = [math]::Round((Get-Counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1).CounterSamples[0].CookedValue, 1)
            memory = [math]::Round((Get-Counter -Counter "\Memory\Available MBytes" -SampleInterval 1 -MaxSamples 1).CounterSamples[0].CookedValue, 0)
            uptime = [math]::Round(((Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime).TotalHours, 1)
            timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
        }
        return $info
    } catch {
        Write-Log "Error getting system info: $($_.Exception.Message)" "ERROR"
        return @{}
    }
}

# Function to send heartbeat to API
function Send-Heartbeat {
    param(
        [hashtable]$SystemInfo,
        [string]$ApiUrl,
        [string]$ServerId
    )
    
    try {
        $payload = @{
            serverId = $ServerId
            username = $SystemInfo.username
            cpu = $SystemInfo.cpu
            memory = $SystemInfo.memory
            status = "active"
            timestamp = $SystemInfo.timestamp
        }

        $body = $payload | ConvertTo-Json -Depth 10
        
        $headers = @{
            'Content-Type' = 'application/json'
        }
        
        $response = Invoke-RestMethod -Uri $ApiUrl -Method Post -Body $body -Headers $headers
        
        Write-Log "Heartbeat sent successfully - Session count: $($response.sessionCount)" "INFO"
        return $true
        
    } catch {
        Write-Log "Failed to send heartbeat: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to get API status
function Get-ApiStatus {
    param([string]$ApiUrl, [string]$ServerId)
    
    try {
        $url = "$ApiUrl?serverId=$ServerId"
        $response = Invoke-RestMethod -Uri $url -Method Get
        
        Write-Log "API Status - Active sessions: $($response.activeSessions.Count), Logged off: $($response.loggedOffUsers.Count)" "INFO"
        
        if ($response.loggedOffUsers.Count -gt 0) {
            Write-Log "Users logged off: $($response.loggedOffUsers -join ', ')" "STATUS"
        }
        
        return $response
        
    } catch {
        Write-Log "Failed to get API status: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# Main monitoring loop
Write-Log "Starting API-based Server Monitor" "INFO"
Write-Log "Config file: $ConfigFile" "INFO"
Write-Log "API URL: $ApiUrl" "INFO"
Write-Log "Server ID: $ServerId" "INFO"
Write-Log "Heartbeat interval: $HeartbeatInterval seconds" "INFO"
Write-Log "Log file: $LogFile" "INFO"

$lastHeartbeat = $null

try {
    while ($true) {
        $systemInfo = Get-SystemInfo
        
        if ($systemInfo.Count -gt 0) {
            # Send heartbeat
            $heartbeatSuccess = Send-Heartbeat -SystemInfo $systemInfo -ApiUrl $ApiUrl -ServerId $ServerId
            
            if ($heartbeatSuccess) {
                $lastHeartbeat = Get-Date
                
                # Log system info
                $logMessage = "System - User: $($systemInfo.username), CPU: $($systemInfo.cpu)%, Memory: $($systemInfo.memory) MB, Uptime: $($systemInfo.uptime) hours"
                Write-Log $logMessage "INFO"
                
                # Get API status (check for logoffs)
                Get-ApiStatus -ApiUrl $ApiUrl -ServerId $ServerId
            }
        }
        
        # If test mode, just run once
        if ($Test) {
            Write-Log "Test mode - exiting after one heartbeat" "INFO"
            break
        }
        
        # Wait for next heartbeat
        Start-Sleep -Seconds $HeartbeatInterval
    }
    
} catch {
    Write-Log "Monitor error: $($_.Exception.Message)" "ERROR"
} finally {
    Write-Log "API monitor stopped" "INFO"
} 