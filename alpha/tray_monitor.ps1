# System Tray Monitor - Windows Forms Application
# Runs in system tray, survives logoff, auto-starts on login

param(
    [string]$ApiUrl = "https://who-is-using-the-server.vercel.app/api",
    [int]$CheckInterval = 20
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables
$script:monitorJob = $null
$script:trayIcon = $null
$script:contextMenu = $null
$script:mainForm = $null
$script:ApiUrl = $ApiUrl
$script:CheckInterval = $CheckInterval

function Start-MonitorJob {
    Write-Host "Starting monitor job..." -ForegroundColor Green

    $scriptBlock = {
        param($ApiUrl, $CheckInterval)

        # Import the monitor functions
        $monitorScript = Join-Path $PSScriptRoot "test_session_monitor.ps1"
        if (Test-Path $monitorScript) {
            # Source the monitor script (this is a simplified version)
            . $monitorScript

            # Run the monitoring logic in a loop
            $script:LastDetectedUsers = @()
            $script:ServerId = $env:COMPUTERNAME

            while ($true) {
                try {
                    # Get active users
                    $currentUsers = Get-ActiveUsers

                    # Check for new logins
                    $newUsers = $currentUsers | Where-Object { $_ -notin $script:LastDetectedUsers }
                    foreach ($user in $newUsers) {
                        Send-LoginNotification -username $user
                    }

                    # Send keep-alive for active users
                    foreach ($user in $currentUsers) {
                        Send-KeepAliveNotification -username $user
                    }

                    # Check for logouts
                    $loggedOutUsers = $script:LastDetectedUsers | Where-Object { $_ -notin $currentUsers }
                    foreach ($user in $loggedOutUsers) {
                        Send-LogoutNotification -username $user
                    }

                    $script:LastDetectedUsers = $currentUsers

                    Start-Sleep -Seconds $CheckInterval
                } catch {
                    Write-Host "Monitor job error: $($_.Exception.Message)" -ForegroundColor Red
                    Start-Sleep -Seconds $CheckInterval
                }
            }
        }
    }

    $script:monitorJob = Start-Job -ScriptBlock $scriptBlock -ArgumentList $ApiUrl, $CheckInterval
}

function Stop-MonitorJob {
    if ($script:monitorJob) {
        Write-Host "Stopping monitor job..." -ForegroundColor Yellow
        Stop-Job $script:monitorJob
        Remove-Job $script:monitorJob
        $script:monitorJob = $null
    }
}

function Show-Status {
    $statusMessage = "Session Monitor Status`n"

    if ($script:monitorJob) {
        $jobStatus = $script:monitorJob.State
        $statusMessage += "Job Status: $jobStatus`n"
        $statusMessage += "Check Interval: $script:CheckInterval seconds`n"
        $statusMessage += "API URL: $($script:ApiUrl -replace '^https?://([^/]+).*', '$1')`n"

        # Get current timestamp
        $currentTime = Get-Date -Format "HH:mm:ss"
        $statusMessage += "Last Update: $currentTime`n"

        # Show active users count if available
        try {
            $activeUsers = Get-ActiveUsers
            $statusMessage += "Active Users: $($activeUsers.Count)"
        } catch {
            $statusMessage += "Active Users: Unknown"
        }

        $script:trayIcon.ShowBalloonTip(5000, "Session Monitor - Running", $statusMessage, [System.Windows.Forms.ToolTipIcon]::Info)
    } else {
        $statusMessage += "Monitor: STOPPED`n"
        $statusMessage += "Click 'Restart Monitor' to start"
        $script:trayIcon.ShowBalloonTip(5000, "Session Monitor - Stopped", $statusMessage, [System.Windows.Forms.ToolTipIcon]::Warning)
    }
}

function Create-TrayIcon {
    # Create context menu
    $script:contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

    $statusItem = $script:contextMenu.Items.Add("Show Status")
    $statusItem.Add_Click({ Show-Status }) | Out-Null

    $script:contextMenu.Items.Add("-") | Out-Null  # Separator

    $restartItem = $script:contextMenu.Items.Add("Restart Monitor")
    $restartItem.Add_Click({
        Stop-MonitorJob
        Start-Sleep -Seconds 2
        Start-MonitorJob
        $trayIcon.ShowBalloonTip(2000, "Session Monitor", "Monitor restarted", [System.Windows.Forms.ToolTipIcon]::Info)
    }) | Out-Null

    $script:contextMenu.Items.Add("-") | Out-Null  # Separator

    $exitItem = $script:contextMenu.Items.Add("Exit")
    $exitItem.Add_Click({
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Stop the Session Monitor?",
            "Confirm Exit",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            Stop-MonitorJob
            $script:mainForm.Close()
        }
    }) | Out-Null

    # Create tray icon
    $script:trayIcon = New-Object System.Windows.Forms.NotifyIcon
    $script:trayIcon.Icon = [System.Drawing.SystemIcons]::Information
    $script:trayIcon.Text = "Session Monitor - Running"
    $script:trayIcon.ContextMenuStrip = $script:contextMenu
    $script:trayIcon.Visible = $true

    # Single-click to show status
    $script:trayIcon.Add_Click({ Show-Status })

    # Double-click also shows status (for compatibility)
    $script:trayIcon.Add_DoubleClick({ Show-Status })

    # Show startup notification
    $script:trayIcon.ShowBalloonTip(3000, "Session Monitor", "Monitor started in system tray", [System.Windows.Forms.ToolTipIcon]::Info)
}

function Install-StartupShortcut {
    $startupFolder = [Environment]::GetFolderPath("Startup")
    $shortcutPath = Join-Path $startupFolder "Session Monitor Tray.lnk"

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.Description = "Session Monitor Tray Application"
    $shortcut.Save()

    Write-Host "✅ Installed startup shortcut: $shortcutPath" -ForegroundColor Green
}

# Main application
try {
    Write-Host "Session Monitor Tray Application" -ForegroundColor Cyan
    Write-Host "API URL: $ApiUrl" -ForegroundColor Yellow
    Write-Host "Check Interval: $CheckInterval seconds" -ForegroundColor Yellow
    Write-Host "Right-click tray icon for options" -ForegroundColor Green
    Write-Host ""

    # Install startup shortcut if requested
    if ($args -contains "-InstallStartup") {
        Install-StartupShortcut
        exit
    }

    # Create Windows Forms application
    $script:mainForm = New-Object System.Windows.Forms.Form
    $script:mainForm.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
    $script:mainForm.ShowInTaskbar = $false
    $script:mainForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $script:mainForm.Width = 1
    $script:mainForm.Height = 1

    # Create tray icon and menu
    Create-TrayIcon

    # Start the monitor job
    Start-MonitorJob

    # Run the application
    [System.Windows.Forms.Application]::Run($script:mainForm)

} catch {
    Write-Host "Critical error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Stop-MonitorJob
    if ($script:trayIcon) {
        $script:trayIcon.Dispose()
    }
}
