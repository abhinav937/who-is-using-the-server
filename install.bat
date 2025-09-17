@echo off
echo ========================================
echo Session Monitor - Install
echo ========================================
echo.

REM Check if PowerShell is available
powershell -Command "Write-Host 'PowerShell available'" >nul 2>&1
if errorlevel 1 (
    echo ERROR: PowerShell is not available on this system.
    echo Please install PowerShell or run on a supported Windows version.
    pause
    exit /b 1
)

echo Installing Session Monitor with tray icon...
echo.

REM Launch PowerShell directly and hidden
start "" powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -Install

echo Installation started. Check system tray for the monitor icon.
echo This window will close automatically.

REM Small delay to let PowerShell start
ping -n 2 127.0.0.1 >nul

REM Exit immediately
exit 