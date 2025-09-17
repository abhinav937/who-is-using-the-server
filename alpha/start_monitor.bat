@echo off
REM Simple batch file to start the session monitor in background
REM This can be added to Windows startup folder

echo Starting Session Monitor...
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0test_session_monitor.ps1"
echo Monitor started in background.
