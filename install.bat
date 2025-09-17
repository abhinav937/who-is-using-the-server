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

REM Run the PowerShell setup script
powershell -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -Install

echo.
pause 