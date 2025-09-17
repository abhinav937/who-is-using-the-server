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

REM Run the PowerShell setup script completely hidden - batch file will exit immediately
start "" /B powershell -WindowStyle Hidden -ExecutionPolicy Bypass -Command "& { & '%~dp0setup.ps1' -Install }" >nul 2>&1

echo Installation started. Check system tray for the monitor icon.
echo This window will close automatically.

REM Exit immediately
exit 