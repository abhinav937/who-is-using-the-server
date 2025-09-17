@echo off
echo ========================================
echo Session Monitor - Uninstall
echo ========================================
echo.

echo Uninstalling Session Monitor...
echo.

REM Run the PowerShell setup script completely hidden - batch file will exit immediately
start "" /B powershell -WindowStyle Hidden -ExecutionPolicy Bypass -Command "& { & '%~dp0setup.ps1' -Uninstall }" >nul 2>&1

echo Uninstallation completed. This window will close automatically.

REM Exit immediately
exit 