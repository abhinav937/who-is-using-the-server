@echo off
echo Starting Server Monitor (User Level)...
echo.

REM Check if PowerShell is available
powershell -Command "Get-Host" >nul 2>&1
if errorlevel 1 (
    echo Error: PowerShell is not available
    pause
    exit /b 1
)

REM Run the PowerShell script
powershell -ExecutionPolicy Bypass -File "%~dp0api_monitor.ps1" -Mode auto -Interval 30

REM Check exit code
if errorlevel 1 (
    echo.
    echo Server Monitor exited with errors.
    echo Check the logs above for details.
) else (
    echo.
    echo Server Monitor stopped gracefully.
)

pause 