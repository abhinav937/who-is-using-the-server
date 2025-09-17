# Server Monitor - One-Click Uninstall (PowerShell)
# No admin access required

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Server Monitor - One-Click Uninstall" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Removing startup script..." -ForegroundColor Yellow

# Remove startup script
$StartupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$ScriptName = "server_monitor.bat"
$StartupScriptPath = "$StartupFolder\$ScriptName"

if (Test-Path $StartupScriptPath) {
    Remove-Item $StartupScriptPath -Force
    Write-Host "- Removed startup script: $StartupScriptPath" -ForegroundColor Green
} else {
    Write-Host "- Startup script not found (already removed)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Removing desktop shortcut..." -ForegroundColor Yellow

# Remove desktop shortcut
$Desktop = "$env:USERPROFILE\Desktop"
$ShortcutName = "Server Monitor.lnk"
$ShortcutPath = "$Desktop\$ShortcutName"

if (Test-Path $ShortcutPath) {
    Remove-Item $ShortcutPath -Force
    Write-Host "- Removed desktop shortcut: $ShortcutPath" -ForegroundColor Green
} else {
    Write-Host "- Desktop shortcut not found (already removed)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Stopping any running monitor processes..." -ForegroundColor Yellow

# Stop any running monitor processes
try {
    Get-Process | Where-Object {
        $_.ProcessName -eq 'powershell' -and 
        $_.CommandLine -like '*api_monitor.ps1*'
    } | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "- Stopped running monitor processes" -ForegroundColor Green
} catch {
    Write-Host "- No running processes found" -ForegroundColor Yellow
}

Write-Host "" 
Write-Host "Removing autorun (Run key) and scheduled tasks..." -ForegroundColor Yellow

try {
    # Remove HKCU Run key
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $runName = "ServerMonitor"
    if (Get-ItemProperty -Path $runKey -Name $runName -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $runKey -Name $runName -Force
        Write-Host "- Removed HKCU Run entry" -ForegroundColor Green
    }
} catch {
    Write-Host "- Failed to remove Run entry (may not exist)" -ForegroundColor Yellow
}

try {
    # Remove Scheduled Tasks
    $taskNameLogon = "ServerMonitor-AtLogon"
    $taskNameReconnect = "ServerMonitor-OnReconnect"
    Unregister-ScheduledTask -TaskName $taskNameLogon -Confirm:$false -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskNameReconnect -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "- Removed scheduled tasks (if present)" -ForegroundColor Green
} catch {
    Write-Host "- Scheduled tasks not found or removal failed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Uninstall completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "What was removed:" -ForegroundColor White
Write-Host "- Startup script" -ForegroundColor White
Write-Host "- Desktop shortcut" -ForegroundColor White
Write-Host "- Running processes stopped" -ForegroundColor White
Write-Host ""
Write-Host "Note: Configuration files (config.env) were not removed." -ForegroundColor Yellow
Write-Host "If you want to remove them completely, delete the entire folder." -ForegroundColor Yellow
Write-Host ""
Read-Host "Press Enter to continue" 