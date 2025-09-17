# Session Monitor Setup Script
# Elegant installation and uninstallation for the tray monitor

param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Status,
    [switch]$Start,
    [switch]$Stop,
    [string]$ApiUrl = "https://who-is-using-the-server.vercel.app/api",
    [int]$CheckInterval = 20
)

$scriptPath = Join-Path $PSScriptRoot "api_monitor.ps1"
$startupFolder = [Environment]::GetFolderPath("Startup")
$startupShortcut = Join-Path $startupFolder "Session Monitor.lnk"

function Show-Status {
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host "Session Monitor Status" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host ""

    # Check if startup shortcut exists
    $startupExists = Test-Path $startupShortcut
    Write-Host "Auto-start on login: $(if ($startupExists) { 'ENABLED' } else { 'DISABLED' })" -ForegroundColor $(if ($startupExists) { 'Green' } else { 'Yellow' })

    # Check if monitor is currently running
    $runningProcesses = Get-Process | Where-Object { $_.ProcessName -eq 'powershell' -and $_.CommandLine -like '*api_monitor.ps1*' }
    Write-Host "Monitor running: $(if ($runningProcesses.Count -gt 0) { 'YES' } else { 'NO' })" -ForegroundColor $(if ($runningProcesses.Count -gt 0) { 'Green' } else { 'Yellow' })

    if ($runningProcesses.Count -gt 0) {
        Write-Host "Running processes: $($runningProcesses.Count)" -ForegroundColor Gray
    }

    # Show configuration
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "  API URL: $ApiUrl" -ForegroundColor Gray
    Write-Host "  Check Interval: $CheckInterval seconds" -ForegroundColor Gray
    Write-Host "  Script Path: $scriptPath" -ForegroundColor Gray

    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  .\setup.ps1 -Install     # Install and start monitor" -ForegroundColor Gray
    Write-Host "  .\setup.ps1 -Uninstall   # Stop and remove monitor" -ForegroundColor Gray
    Write-Host "  .\setup.ps1 -Start       # Start monitor manually" -ForegroundColor Gray
    Write-Host "  .\setup.ps1 -Stop        # Stop monitor" -ForegroundColor Gray
    Write-Host "  .\setup.ps1 -Status      # Show this status" -ForegroundColor Gray
}

function Install-Monitor {
    Write-Host "=================================" -ForegroundColor Green
    Write-Host "Installing Session Monitor" -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Green
    Write-Host ""

    # Check if script exists
    if (-not (Test-Path $scriptPath)) {
        Write-Host "❌ Error: Monitor script not found at $scriptPath" -ForegroundColor Red
        exit 1
    }

    # Stop any existing instances
    Write-Host "Stopping existing monitor instances..." -ForegroundColor Yellow
    Stop-Monitor

    # Install startup shortcut
    Write-Host "Installing auto-start shortcut..." -ForegroundColor Cyan
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($startupShortcut)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`" -ApiUrl `"$ApiUrl`" -CheckInterval $CheckInterval"
        $shortcut.WorkingDirectory = $PSScriptRoot
        $shortcut.Description = "Session Monitor Tray Application - Auto-start"
        $shortcut.Save()
        Write-Host "✅ Auto-start shortcut installed: $startupShortcut" -ForegroundColor Green
    } catch {
        Write-Host "❌ Error creating startup shortcut: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }

    # Start the monitor
    Write-Host "Starting monitor..." -ForegroundColor Cyan
    Start-Monitor

    Write-Host ""
    Write-Host "🎉 Installation completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "What was installed:" -ForegroundColor Cyan
    Write-Host "  • Auto-start shortcut in startup folder" -ForegroundColor Gray
    Write-Host "  • Monitor running in system tray" -ForegroundColor Gray
    Write-Host ""
    Write-Host "The monitor will:" -ForegroundColor Yellow
    Write-Host "  • Start automatically on login" -ForegroundColor Gray
    Write-Host "  • Run hidden in the background" -ForegroundColor Gray
    Write-Host "  • Show a tray icon for status/control" -ForegroundColor Gray
    Write-Host "  • Send login/heartbeat/logout notifications" -ForegroundColor Gray
}

function Uninstall-Monitor {
    Write-Host "=================================" -ForegroundColor Yellow
    Write-Host "Uninstalling Session Monitor" -ForegroundColor Yellow
    Write-Host "=================================" -ForegroundColor Yellow
    Write-Host ""

    # Stop monitor
    Write-Host "Stopping monitor..." -ForegroundColor Cyan
    Stop-Monitor

    # Remove startup shortcut
    Write-Host "Removing auto-start shortcut..." -ForegroundColor Cyan
    if (Test-Path $startupShortcut) {
        Remove-Item $startupShortcut -Force
        Write-Host "✅ Removed startup shortcut: $startupShortcut" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  Startup shortcut not found (already removed)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "🗑️  Uninstallation completed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "What was removed:" -ForegroundColor Cyan
    Write-Host "  • Auto-start shortcut" -ForegroundColor Gray
    Write-Host "  • Running monitor processes" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Note: Configuration files (config.env) were not removed." -ForegroundColor Yellow
    Write-Host "If you want to remove everything, delete the entire folder." -ForegroundColor Gray
}

function Start-Monitor {
    Write-Host "Starting Session Monitor..." -ForegroundColor Green
    try {
        $process = Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden", "-ExecutionPolicy Bypass", "-File", "`"$scriptPath`"", "-ApiUrl", "`"$ApiUrl`"", "-CheckInterval", $CheckInterval -NoNewWindow -PassThru
        Write-Host "✅ Monitor started (PID: $($process.Id))" -ForegroundColor Green
        Write-Host "Check the system tray for the monitor icon." -ForegroundColor Cyan
    } catch {
        Write-Host "❌ Error starting monitor: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Stop-Monitor {
    Write-Host "Stopping Session Monitor..." -ForegroundColor Yellow
    $stopped = $false

    # Stop PowerShell processes running the monitor script
    $processes = Get-Process | Where-Object { $_.ProcessName -eq 'powershell' -and $_.CommandLine -like '*api_monitor.ps1*' }
    if ($processes.Count -gt 0) {
        $processes | Stop-Process -Force
        Write-Host "✅ Stopped $($processes.Count) monitor process(es)" -ForegroundColor Green
        $stopped = $true
    }

    # Also stop any Windows Forms applications that might be running
    $formsProcesses = Get-Process | Where-Object { $_.MainWindowTitle -like '*Session Monitor*' -or $_.ProcessName -eq 'powershell' -and $_.CommandLine -like '*System.Windows.Forms*' }
    if ($formsProcesses.Count -gt 0) {
        $formsProcesses | Stop-Process -Force
        Write-Host "✅ Stopped $($formsProcesses.Count) UI process(es)" -ForegroundColor Green
        $stopped = $true
    }

    if (-not $stopped) {
        Write-Host "ℹ️  No running monitor processes found" -ForegroundColor Gray
    }
}

# Main logic
if ($Install) {
    Install-Monitor
} elseif ($Uninstall) {
    Uninstall-Monitor
} elseif ($Start) {
    Start-Monitor
} elseif ($Stop) {
    Stop-Monitor
} elseif ($Status) {
    Show-Status
} else {
    # Default: Show help
    Write-Host "Session Monitor Setup" -ForegroundColor Cyan
    Write-Host "====================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\setup.ps1 -Install     # Install and start monitor" -ForegroundColor Gray
    Write-Host "  .\setup.ps1 -Uninstall   # Stop and remove monitor" -ForegroundColor Gray
    Write-Host "  .\setup.ps1 -Start       # Start monitor manually" -ForegroundColor Gray
    Write-Host "  .\setup.ps1 -Stop        # Stop monitor" -ForegroundColor Gray
    Write-Host "  .\setup.ps1 -Status      # Show status" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\setup.ps1 -Install" -ForegroundColor Gray
    Write-Host "  .\setup.ps1 -Install -ApiUrl 'https://custom-api.com/api' -CheckInterval 30" -ForegroundColor Gray
    Write-Host "  .\setup.ps1 -Status" -ForegroundColor Gray
}
