@echo off
echo ========================================
echo Server Monitor - One-Click Uninstall
echo ========================================
echo.

echo Removing startup script...
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SCRIPT_NAME=server_monitor.bat"

if exist "%STARTUP_FOLDER%\%SCRIPT_NAME%" (
    del "%STARTUP_FOLDER%\%SCRIPT_NAME%"
    echo - Removed startup script: %STARTUP_FOLDER%\%SCRIPT_NAME%
) else (
    echo - Startup script not found (already removed)
)

echo.
echo Removing desktop shortcut...
set "DESKTOP=%USERPROFILE%\Desktop"
set "SHORTCUT_NAME=Server Monitor.lnk"

if exist "%DESKTOP%\%SHORTCUT_NAME%" (
    del "%DESKTOP%\%SHORTCUT_NAME%"
    echo - Removed desktop shortcut: %DESKTOP%\%SHORTCUT_NAME%
) else (
    echo - Desktop shortcut not found (already removed)
)

echo.
echo Stopping any running monitor processes...
powershell -Command "Get-Process | Where-Object {$_.ProcessName -eq 'powershell' -and $_.CommandLine -like '*api_monitor.ps1*'} | Stop-Process -Force" >nul 2>&1

echo.
echo Removing autorun (Run key) and scheduled tasks...
REM Remove HKCU Run entry
powershell -Command "Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'ServerMonitor' -Force -ErrorAction SilentlyContinue" >nul 2>&1

REM Remove scheduled tasks
schtasks /Delete /TN "ServerMonitor-AtLogon" /F >nul 2>&1
schtasks /Delete /TN "ServerMonitor-OnReconnect" /F >nul 2>&1

echo.
echo ========================================
echo Uninstall completed successfully!
echo ========================================
echo.
echo What was removed:
echo - Startup script
echo - Desktop shortcut
echo - Running processes stopped
echo.
echo Note: Configuration files (config.env) were not removed.
echo If you want to remove them completely, delete the entire folder.
echo.
pause 