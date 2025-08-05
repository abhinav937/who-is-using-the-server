@echo off
echo API-based Server Monitor
echo =======================
echo.
echo This will send heartbeat data to the Vercel API
echo for better logout detection
echo.
echo Press Ctrl+C to stop the monitor
echo.

powershell.exe -ExecutionPolicy Bypass -File "api_monitor.ps1" -ConfigFile "config.env" -ServerId "%COMPUTERNAME%"

pause 