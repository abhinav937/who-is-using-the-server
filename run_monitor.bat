@echo off
echo Starting Session Monitor (Tray Mode)...
echo.

REM Check if PowerShell is available
powershell -Command "Get-Host" >nul 2>&1
if errorlevel 1 (
    echo Error: PowerShell is not available
    pause
    exit /b 1
)

echo Starting monitor in background (tray icon will appear)...
echo This window will close automatically.
echo Use the system tray icon to control the monitor.
echo.

REM Launch monitor completely hidden - batch file will exit immediately
start "" /B powershell -WindowStyle Hidden -ExecutionPolicy Bypass -Command "& { & '%~dp0api_monitor.ps1' }" >nul 2>&1

echo Monitor started successfully.

REM Exit immediately
exit 