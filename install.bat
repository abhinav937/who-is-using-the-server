@echo off
echo ========================================
echo Server Monitor - One-Click Install
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

echo Creating startup script...
echo.

REM Create the startup script in user's startup folder
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SCRIPT_NAME=server_monitor.bat"

REM Create the startup script
echo @echo off > "%STARTUP_FOLDER%\%SCRIPT_NAME%"
echo cd /d "%~dp0" >> "%STARTUP_FOLDER%\%SCRIPT_NAME%"
echo powershell -ExecutionPolicy Bypass -File "%~dp0api_monitor.ps1" >> "%STARTUP_FOLDER%\%SCRIPT_NAME%"

echo Creating desktop shortcut...
echo.

REM Create desktop shortcut
set "DESKTOP=%USERPROFILE%\Desktop"
set "SHORTCUT_NAME=Server Monitor.lnk"

REM Create VBS script to create shortcut
echo Set oWS = WScript.CreateObject("WScript.Shell") > "%TEMP%\CreateShortcut.vbs"
echo sLinkFile = "%DESKTOP%\%SHORTCUT_NAME%" >> "%TEMP%\CreateShortcut.vbs"
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> "%TEMP%\CreateShortcut.vbs"
echo oLink.TargetPath = "%~dp0run_monitor.bat" >> "%TEMP%\CreateShortcut.vbs"
echo oLink.WorkingDirectory = "%~dp0" >> "%TEMP%\CreateShortcut.vbs"
echo oLink.Description = "Server Monitor - Start monitoring" >> "%TEMP%\CreateShortcut.vbs"
echo oLink.IconLocation = "%~dp0run_monitor.bat,0" >> "%TEMP%\CreateShortcut.vbs"
echo oLink.Save >> "%TEMP%\CreateShortcut.vbs"

cscript //nologo "%TEMP%\CreateShortcut.vbs"
del "%TEMP%\CreateShortcut.vbs"

echo Creating config file...
echo.

REM Create default config if it doesn't exist
if not exist "config.env" (
    echo API_URL=https://who-is-using-the-server.vercel.app/api > config.env
    echo HEARTBEAT_INTERVAL=30 >> config.env
    echo MONITOR_MODE=auto >> config.env
)

echo ========================================
echo Installation completed successfully!
echo ========================================
echo.
echo What was installed:
echo - Startup script: %STARTUP_FOLDER%\%SCRIPT_NAME%
echo - Desktop shortcut: %DESKTOP%\%SHORTCUT_NAME%
echo - Configuration: config.env
echo.
echo The server monitor will start automatically on login.
echo You can also run it manually using the desktop shortcut.
echo.
echo To uninstall, run: uninstall.bat
echo.
pause 