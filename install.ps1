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
Read-Host "Press Enter to continue" 