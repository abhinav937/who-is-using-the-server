@echo off
echo Installing API-based Server Monitor
echo ==================================
echo.
echo This will set up the API monitor to run automatically when you log in
echo.

REM Create a startup script
echo @echo off > "%APPDATA%\api_monitor_startup.bat"
echo cd /d "%~dp0" >> "%APPDATA%\api_monitor_startup.bat"
echo powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0api_monitor.ps1" -ConfigFile "%~dp0config.env" -ServerId "%COMPUTERNAME%" >> "%APPDATA%\api_monitor_startup.bat"

REM Add to Windows startup
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "ApiServerMonitor" /t REG_SZ /d "\"%APPDATA%\api_monitor_startup.bat\"" /f

echo.
echo Installation complete!
echo.
echo IMPORTANT: You need to:
echo 1. Deploy the API to Vercel (see DEPLOYMENT.md)
echo 2. Update the API_URL in config.env
echo 3. Set the TEAMS_WEBHOOK_URL environment variable in Vercel
echo.
echo The API monitor will start automatically when you log in.
echo You can stop it anytime by running: uninstall_api_monitor.bat
echo.
pause 