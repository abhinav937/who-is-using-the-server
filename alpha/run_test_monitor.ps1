# Simple launcher for test session monitor
# This helps run the monitor in the background without admin privileges

param(
    [switch]$Background,
    [switch]$Minimized,
    [switch]$Stop,
    [switch]$InstallStartup,  # Add to user startup
    [switch]$RemoveStartup    # Remove from user startup
)

$scriptPath = Join-Path $PSScriptRoot "test_session_monitor.ps1"

$startupFolder = [Environment]::GetFolderPath("Startup")
$startupShortcut = Join-Path $startupFolder "Session Monitor.lnk"

if ($InstallStartup) {
    Write-Host "Installing Session Monitor with tray icon to startup..." -ForegroundColor Green
    Write-Host "This will install the tray version for better control and visibility." -ForegroundColor Cyan

    # Use the tray monitor for startup (provides tray icon + monitoring)
    $trayScript = Join-Path $PSScriptRoot "tray_monitor.ps1"
    if (Test-Path $trayScript) {
        # Create a shortcut in startup folder that runs the tray monitor
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($startupShortcut)
        $shortcut.TargetPath = "powershell.exe"
        $argsString = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$trayScript`""
        $shortcut.Arguments = $argsString
        $shortcut.WorkingDirectory = $PSScriptRoot
        $shortcut.Description = "Session Monitor Tray - Auto-start on login"
        $shortcut.Save()

        Write-Host "✅ Installed tray monitor to startup: $startupShortcut" -ForegroundColor Green
        Write-Host "📱 Tray icon will appear automatically when you log in" -ForegroundColor Cyan
        Write-Host "🔄 Monitor will restart automatically on system startup" -ForegroundColor Cyan
        Write-Host "" -ForegroundColor Cyan
        Write-Host "💡 Tray Features:" -ForegroundColor Yellow
        Write-Host "   • Click icon for status" -ForegroundColor Gray
        Write-Host "   • Right-click for menu (Restart/Exit)" -ForegroundColor Gray
        Write-Host "   • Survives sign-out/logoff" -ForegroundColor Gray
    } else {
        Write-Host "❌ Tray monitor script not found: $trayScript" -ForegroundColor Red
        Write-Host "Please ensure tray_monitor.ps1 exists in the same directory." -ForegroundColor Yellow
    }
    exit
}

if ($RemoveStartup) {
    Write-Host "Removing from user startup folder..." -ForegroundColor Yellow

    if (Test-Path $startupShortcut) {
        Remove-Item $startupShortcut -Force
        Write-Host "✅ Removed from startup: $startupShortcut" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Startup shortcut not found." -ForegroundColor Yellow
    }
    exit
}

if ($Stop) {
    Write-Host "Stopping background jobs..." -ForegroundColor Yellow
    Get-Job | Where-Object { $_.Command -like "*test_session_monitor*" } | Stop-Job
    Get-Job | Where-Object { $_.Command -like "*test_session_monitor*" } | Remove-Job
    Write-Host "Done." -ForegroundColor Green
    exit
}

if ($Background) {
    Write-Host "Starting test session monitor as background job..." -ForegroundColor Green
    $job = Start-Job -ScriptBlock {
        param($path)
        & $path
    } -ArgumentList $scriptPath

    Write-Host "Job started with ID: $($job.Id)" -ForegroundColor Cyan
    Write-Host "Use 'Get-Job' to check status, or run this script with -Stop to stop it." -ForegroundColor Yellow
    exit
}

if ($Minimized) {
    Write-Host "Starting test session monitor in minimized window..." -ForegroundColor Green
    Start-Process powershell.exe -ArgumentList "-WindowStyle Minimized", "-Command", "& '$scriptPath'" -NoNewWindow
    Write-Host "Monitor started in background. Check Task Manager for powershell.exe processes." -ForegroundColor Cyan
    exit
}

# Default: Run normally
Write-Host "Starting test session monitor (normal mode)..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop." -ForegroundColor Yellow
Write-Host ""
Write-Host "💡 Tip: Use these commands for persistence:" -ForegroundColor Cyan
Write-Host "   .\run_test_monitor.ps1 -InstallStartup   # Install tray monitor + auto-start" -ForegroundColor Gray
Write-Host "   .\run_test_monitor.ps1 -RemoveStartup    # Remove auto-start" -ForegroundColor Gray
Write-Host "   .\run_tray_monitor.ps1 -RunHidden        # Run tray monitor hidden" -ForegroundColor Gray
Write-Host "   .\run_test_monitor.ps1 -Stop             # Stop background jobs" -ForegroundColor Gray
Write-Host ""
& $scriptPath
