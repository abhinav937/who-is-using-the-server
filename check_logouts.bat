@echo off
echo Logout Check Script
echo ===================
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0check_logouts.ps1" %*

echo.
echo Press any key to exit...
pause >nul 