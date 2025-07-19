# Simple Google Forms API OAuth test
# Tests authentication with improved PowerShell compatibility

param(
    [Parameter(Mandatory = $false)]
    [string]$CredentialsPath = ".\config\google-credentials.json"
)

Write-Host "Testing Google Forms API Authentication..." -ForegroundColor Green

try {
    # Load credentials
    if (-not (Test-Path $CredentialsPath)) {
        throw "Credentials file not found: $CredentialsPath"
    }
    
    $credentials = Get-Content $CredentialsPath | ConvertFrom-Json
    $clientId = $credentials.installed.client_id
    $clientSecret = $credentials.installed.client_secret
    
    Write-Host "✓ Credentials loaded" -ForegroundColor Green
    Write-Host "  Client ID: $($clientId.Substring(0,20))..." -ForegroundColor Gray
    Write-Host "  Project: $($credentials.installed.project_id)" -ForegroundColor Gray
    
    # Build OAuth URL
    $redirectUri = "http://localhost:8080"
    $scope = "https://www.googleapis.com/auth/forms"
    $state = [System.Guid]::NewGuid().ToString()
    
    $authUrl = "https://accounts.google.com/o/oauth2/auth?" +
               "client_id=$clientId&" +
               "redirect_uri=$([uri]::EscapeDataString($redirectUri))&" +
               "response_type=code&" +
               "scope=$([uri]::EscapeDataString($scope))&" +
               "state=$state&" +
               "access_type=offline&" +
               "prompt=consent"
    
    Write-Host "`n🔐 Manual OAuth Test" -ForegroundColor Yellow
    Write-Host "1. Copy this URL to your browser:" -ForegroundColor White
    Write-Host $authUrl -ForegroundColor Cyan
    Write-Host "`n2. Complete the authorization" -ForegroundColor White
    Write-Host "3. You'll be redirected to localhost:8080 (this will fail)" -ForegroundColor White
    Write-Host "4. Copy the 'code' parameter from the failed URL" -ForegroundColor White
    Write-Host "   Example: http://localhost:8080/?code=YOUR_CODE&state=..." -ForegroundColor Gray
    Write-Host "   Copy just the YOUR_CODE part" -ForegroundColor Gray
    
    $authCode = Read-Host "`nPaste the authorization code here"
    
    if (-not $authCode) {
        throw "No authorization code provided"
    }
    
    Write-Host "`n🔄 Exchanging code for access token..." -ForegroundColor Yellow
    
    # Exchange code for tokens
    $tokenRequest = @{
        client_id = $clientId
        client_secret = $clientSecret
        code = $authCode
        grant_type = "authorization_code"
        redirect_uri = $redirectUri
    }
    
    $tokenResponse = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body $tokenRequest -ContentType "application/x-www-form-urlencoded"
    
    Write-Host "✅ Access token obtained!" -ForegroundColor Green
    
    # Test Forms API
    Write-Host "🧪 Testing Google Forms API..." -ForegroundColor Yellow
    
    $headers = @{
        "Authorization" = "Bearer $($tokenResponse.access_token)"
        "Content-Type" = "application/json"
    }
    
    $testForm = @{
        info = @{
            title = "API Test Form - DELETE ME"
            description = "This is a test form. You can delete this."
        }
    }
    
    $formResponse = Invoke-RestMethod -Uri "https://forms.googleapis.com/v1/forms" -Method Post -Headers $headers -Body ($testForm | ConvertTo-Json -Depth 5)
    
    Write-Host "✅ SUCCESS! Google Forms API is working!" -ForegroundColor Green
    Write-Host "Test form created: https://docs.google.com/forms/d/$($formResponse.formId)/edit" -ForegroundColor Cyan
    
    # Save token for main script
    $tokenData = @{
        access_token = $tokenResponse.access_token
        refresh_token = $tokenResponse.refresh_token
        expires_at = (Get-Date).AddSeconds($tokenResponse.expires_in)
        client_id = $clientId
        client_secret = $clientSecret
    }
    
    $tokenPath = ".\config\google-tokens.json"
    $tokenData | ConvertTo-Json | Set-Content $tokenPath
    Write-Host "✓ Token saved to $tokenPath" -ForegroundColor Green
    
    Write-Host "`n🎉 Authentication successful!" -ForegroundColor Green
    Write-Host "You can now run: .\Generate-SessionFeedbackForms.ps1" -ForegroundColor White
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -match "400.*invalid_grant") {
        Write-Host "`n💡 This usually means:" -ForegroundColor Yellow
        Write-Host "• The authorization code expired (they only last ~10 minutes)" -ForegroundColor White
        Write-Host "• The code was already used" -ForegroundColor White
        Write-Host "• Try the process again with a fresh authorization" -ForegroundColor White
    }
    
    Write-Host "`n🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Ensure redirect URI 'http://localhost:8080' is in Google Cloud Console" -ForegroundColor White
    Write-Host "2. Check OAuth consent screen is configured" -ForegroundColor White
    Write-Host "3. Verify Google Forms API is enabled" -ForegroundColor White
    Write-Host "4. Make sure you're added as a test user" -ForegroundColor White
}
