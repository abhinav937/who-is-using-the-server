# Launcher for System Tray Monitor
param(
    [switch]$InstallStartup,
    [switch]$RunHidden,
    [string]$ApiUrl = "https://who-is-using-the-server.vercel.app/api",
    [int]$CheckInterval = 20
)

$trayScript = Join-Path $PSScriptRoot "tray_monitor.ps1"

if ($InstallStartup) {
    Write-Host "Installing tray monitor to startup..." -ForegroundColor Green
    & $trayScript -InstallStartup
    exit
}

if ($RunHidden) {
    Write-Host "Starting tray monitor (hidden)..." -ForegroundColor Green
    Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden", "-ExecutionPolicy Bypass", "-File", "`"$trayScript`"", "-ApiUrl", "`"$ApiUrl`"", "-CheckInterval", $CheckInterval -NoNewWindow
    Write-Host "Tray monitor started. Check system tray for the icon." -ForegroundColor Cyan
    exit
}

# Default: Run normally (for testing)
Write-Host "Starting tray monitor (normal mode)..." -ForegroundColor Green
Write-Host "Close the window to stop the monitor." -ForegroundColor Yellow
Write-Host ""

& $trayScript -ApiUrl $ApiUrl -CheckInterval $CheckInterval
