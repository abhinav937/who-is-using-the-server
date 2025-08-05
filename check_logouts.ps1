# Logout Check Script
# Manually triggers logout detection on the server monitor API

param(
    [string]$ApiUrl = "https://who-is-using-the-server.vercel.app/api"
)

Write-Host "Logout Check Script" -ForegroundColor Cyan
Write-Host "API URL: $ApiUrl" -ForegroundColor Yellow
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri "$ApiUrl?action=check_logouts" -Method GET -TimeoutSec 30
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] Logout check completed successfully" -ForegroundColor Green
    Write-Host "Response: $($response.message)" -ForegroundColor White
    
} catch {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [ERROR] Logout check failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "Logout check script completed." -ForegroundColor Cyan 