@echo off
echo ========================================
echo Session Monitor - Uninstall
echo ========================================
echo.

echo Uninstalling Session Monitor...
echo.

REM Launch PowerShell directly and hidden
start "" powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -Uninstall

echo Uninstallation completed. This window will close automatically.

REM Small delay to let PowerShell start
ping -n 2 127.0.0.1 >nul

REM Exit immediately
exit 