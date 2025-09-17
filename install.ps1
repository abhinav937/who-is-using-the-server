# Server Monitor - One-Click Install (PowerShell)
# No admin access required

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Server Monitor - One-Click Install" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Creating startup script..." -ForegroundColor Yellow

# Create startup script in user's startup folder
$StartupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$ScriptName = "server_monitor.bat"

# Create the startup script
$StartupScript = @"
@echo off
cd /d "$ScriptDir"
powershell -ExecutionPolicy Bypass -File "$ScriptDir\api_monitor.ps1"
"@

$StartupScript | Out-File -FilePath "$StartupFolder\$ScriptName" -Encoding ASCII

Write-Host "Creating desktop shortcut..." -ForegroundColor Yellow

# Create desktop shortcut
$Desktop = "$env:USERPROFILE\Desktop"
$ShortcutName = "Server Monitor.lnk"

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$Desktop\$ShortcutName")
$Shortcut.TargetPath = "$ScriptDir\run_monitor.bat"
$Shortcut.WorkingDirectory = $ScriptDir
$Shortcut.Description = "Server Monitor - Start monitoring"
$Shortcut.Save()

Write-Host "Creating config file..." -ForegroundColor Yellow

# Create default config if it doesn't exist
$ConfigFile = "$ScriptDir\config.env"
if (-not (Test-Path $ConfigFile)) {
    @"
API_URL=https://who-is-using-the-server.vercel.app/api
HEARTBEAT_INTERVAL=30
MONITOR_MODE=auto
"@ | Out-File -FilePath $ConfigFile -Encoding ASCII
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "What was installed:" -ForegroundColor White
Write-Host "- Startup script: $StartupFolder\$ScriptName" -ForegroundColor White
Write-Host "- Desktop shortcut: $Desktop\$ShortcutName" -ForegroundColor White
Write-Host "- Configuration: $ConfigFile" -ForegroundColor White
Write-Host ""
Write-Host "The server monitor will start automatically on login." -ForegroundColor Yellow
Write-Host "You can also run it manually using the desktop shortcut." -ForegroundColor Yellow
Write-Host ""
Write-Host "To uninstall, run: uninstall.ps1" -ForegroundColor Yellow
Write-Host ""

# Additional auto-start methods to ensure launch on RDP and reconnect
Write-Host "Configuring autorun (Run key) and scheduled tasks..." -ForegroundColor Yellow

try {
    # 1) HKCU Run key (fires on any interactive logon)
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $runName = "ServerMonitor"
    $runValue = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptDir\api_monitor.ps1`""
    New-Item -Path $runKey -Force | Out-Null
    New-ItemProperty -Path $runKey -Name $runName -Value $runValue -PropertyType String -Force | Out-Null
    Write-Host "- Added HKCU Run entry" -ForegroundColor Green

    # 2) Scheduled Task at logon (redundant safety)
    $taskNameLogon = "ServerMonitor-AtLogon"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptDir\api_monitor.ps1`""
    $triggerLogon = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel LeastPrivilege
    Register-ScheduledTask -TaskName $taskNameLogon -Action $action -Trigger $triggerLogon -Principal $principal -Force | Out-Null
    Write-Host "- Created Scheduled Task (AtLogon)" -ForegroundColor Green

    # 3) Scheduled Task on RDP reconnect/connect using event trigger
    $taskNameReconnect = "ServerMonitor-OnReconnect"
    $actionCmd = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptDir\api_monitor.ps1`""
    $xpath = "*[System[Provider[@Name='Microsoft-Windows-TerminalServices-LocalSessionManager'] and (EventID=21 or EventID=25)]]"
    $args = "/Create /TN `"$taskNameReconnect`" /TR `"$actionCmd`" /SC ONEVENT /EC Microsoft-Windows-TerminalServices-LocalSessionManager/Operational /MO `"$xpath`" /F"
    Start-Process schtasks.exe -ArgumentList $args -NoNewWindow -Wait
    Write-Host "- Created Scheduled Task (On RDP Session Connect/Reconnect)" -ForegroundColor Green

} catch {
    Write-Host "[WARN] Failed to fully configure autorun tasks: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "Setup complete. Press Enter to exit." -ForegroundColor Cyan
Read-Host