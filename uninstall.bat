@echo off
echo ========================================
echo Session Monitor - Uninstall
echo ========================================
echo.

echo Uninstalling Session Monitor...
echo.

REM Run the PowerShell setup script
powershell -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -Uninstall

echo.
pause 