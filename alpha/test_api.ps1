# Test API connectivity and manual login
param(
    [string]$ApiUrl = "https://who-is-using-the-server.vercel.app/api"
)

Write-Host "Testing API Connection" -ForegroundColor Cyan
Write-Host "API URL: $ApiUrl" -ForegroundColor Yellow
Write-Host ""

# Test 1: GET request (status check)
Write-Host "Test 1: GET request (status check)" -ForegroundColor Green
try {
    $response = Invoke-RestMethod -Uri $ApiUrl -Method GET -TimeoutSec 10
    Write-Host "✅ GET successful" -ForegroundColor Green
    Write-Host "Response: $($response | ConvertTo-Json -Depth 3)" -ForegroundColor Gray
} catch {
    Write-Host "❌ GET failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 2: POST login request
Write-Host "Test 2: POST login request" -ForegroundColor Green
try {
    $loginData = @{
        action = "login"
        serverId = $env:COMPUTERNAME
        username = $env:USERNAME
    }
    $jsonData = $loginData | ConvertTo-Json -Compress
    Write-Host "Sending: $jsonData" -ForegroundColor Gray

    $response = Invoke-RestMethod -Uri $ApiUrl -Method POST -Body $jsonData -ContentType "application/json" -TimeoutSec 10
    Write-Host "✅ Login successful" -ForegroundColor Green
    Write-Host "Response: $($response | ConvertTo-Json)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Login failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: GET request again to verify login worked
Write-Host "Test 3: GET request after login (should show session)" -ForegroundColor Green
try {
    $response = Invoke-RestMethod -Uri $ApiUrl -Method GET -TimeoutSec 10
    Write-Host "✅ GET after login successful" -ForegroundColor Green
    Write-Host "Response: $($response | ConvertTo-Json -Depth 3)" -ForegroundColor Gray
} catch {
    Write-Host "❌ GET after login failed: $($_.Exception.Message)" -ForegroundColor Red
}
