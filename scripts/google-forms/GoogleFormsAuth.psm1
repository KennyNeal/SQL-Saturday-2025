# Google Forms OAuth 2.0 Authentication Module
# Secure implementation of OAuth 2.0 flow for Google Forms API

function Get-GoogleFormsAccessToken {
    <#
    .SYNOPSIS
        Obtains an access token for Google Forms API using OAuth 2.0
    
    .DESCRIPTION
        Implements secure OAuth 2.0 flow to authenticate with Google Forms API.
        Handles token caching and refresh automatically.
    
    .PARAMETER ClientId
        Google Cloud OAuth 2.0 Client ID
    
    .PARAMETER ClientSecret
        Google Cloud OAuth 2.0 Client Secret (SecureString)
    
    .PARAMETER TokenCachePath
        Path to store cached tokens securely
    
    .EXAMPLE
        $clientSecret = ConvertTo-SecureString "your-secret" -AsPlainText -Force
        $token = Get-GoogleFormsAccessToken -ClientId "your-id" -ClientSecret $clientSecret
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClientId,
        
        [Parameter(Mandatory = $true)]
        [SecureString]$ClientSecret,
        
        [Parameter(Mandatory = $false)]
        [string]$TokenCachePath = "$env:TEMP\google-forms-tokens.json"
    )
    
    $ErrorActionPreference = "Stop"
    
    try {
        # Check for cached valid token first
        $cachedToken = Get-CachedToken -TokenCachePath $TokenCachePath
        if ($cachedToken -and (Test-TokenValidity -Token $cachedToken)) {
            Write-Verbose "Using cached access token"
            return $cachedToken.access_token
        }
        
        # Try to refresh token if available
        if ($cachedToken -and $cachedToken.refresh_token) {
            Write-Verbose "Attempting to refresh access token"
            $refreshedToken = Invoke-TokenRefresh -ClientId $ClientId -ClientSecret $ClientSecret -RefreshToken $cachedToken.refresh_token
            if ($refreshedToken) {
                Save-TokenCache -Token $refreshedToken -TokenCachePath $TokenCachePath
                return $refreshedToken.access_token
            }
        }
        
        # Perform full OAuth 2.0 flow
        Write-Verbose "Starting OAuth 2.0 authorization flow"
        $authCode = Start-OAuth2Flow -ClientId $ClientId
        $token = Invoke-TokenExchange -ClientId $ClientId -ClientSecret $ClientSecret -AuthCode $authCode
        
        # Cache the token
        Save-TokenCache -Token $token -TokenCachePath $TokenCachePath
        
        return $token.access_token
        
    } catch {
        Write-Error "Failed to obtain access token: $($_.Exception.Message)"
        throw
    }
}

function Start-OAuth2Flow {
    param(
        [string]$ClientId
    )
    
    $redirectUri = "http://localhost:8080"
    $scope = "https://www.googleapis.com/auth/forms"
    $state = [System.Guid]::NewGuid().ToString()
    
    # Build authorization URL
    $authUrl = "https://accounts.google.com/o/oauth2/auth?" +
               "client_id=$ClientId&" +
               "redirect_uri=$([uri]::EscapeDataString($redirectUri))&" +
               "response_type=code&" +
               "scope=$([uri]::EscapeDataString($scope))&" +
               "state=$state&" +
               "access_type=offline&" +
               "prompt=consent"
    
    # Start local web server to capture redirect
    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("$redirectUri/")
    $listener.Start()
    
    try {
        # Open browser for user authorization
        Write-Host "Opening browser for Google authorization..."
        Write-Host "If browser doesn't open automatically, visit: $authUrl"
        Start-Process $authUrl
        
        # Wait for callback
        Write-Host "Waiting for authorization response..."
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        # Send response to browser
        $responseString = "<html><body><h1>Authorization Complete</h1><p>You can close this window.</p></body></html>"
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseString)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.OutputStream.Close()
        
        # Extract authorization code
        $query = [System.Web.HttpUtility]::ParseQueryString($request.Url.Query)
        $authCode = $query["code"]
        $returnedState = $query["state"]
        
        if (-not $authCode) {
            throw "Authorization failed: No authorization code received"
        }
        
        if ($returnedState -ne $state) {
            throw "Authorization failed: State parameter mismatch"
        }
        
        return $authCode
        
    } finally {
        $listener.Stop()
    }
}

function Invoke-TokenExchange {
    param(
        [string]$ClientId,
        [SecureString]$ClientSecret,
        [string]$AuthCode
    )
    
    $clientSecretPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ClientSecret)
    )
    
    try {
        $tokenRequest = @{
            client_id = $ClientId
            client_secret = $clientSecretPlain
            code = $AuthCode
            grant_type = "authorization_code"
            redirect_uri = "http://localhost:8080"
        }
        
        $response = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body $tokenRequest -ContentType "application/x-www-form-urlencoded"
        
        # Add expiration timestamp
        $response | Add-Member -MemberType NoteProperty -Name "expires_at" -Value ([DateTimeOffset]::UtcNow.AddSeconds($response.expires_in).ToUnixTimeSeconds())
        
        return $response
        
    } finally {
        # Clear sensitive data
        if ($clientSecretPlain) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR([System.Runtime.InteropServices.Marshal]::StringToBSTR($clientSecretPlain))
        }
    }
}

function Invoke-TokenRefresh {
    param(
        [string]$ClientId,
        [SecureString]$ClientSecret,
        [string]$RefreshToken
    )
    
    $clientSecretPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ClientSecret)
    )
    
    try {
        $refreshRequest = @{
            client_id = $ClientId
            client_secret = $clientSecretPlain
            refresh_token = $RefreshToken
            grant_type = "refresh_token"
        }
        
        $response = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body $refreshRequest -ContentType "application/x-www-form-urlencoded"
        
        # Preserve refresh token if not provided in response
        if (-not $response.refresh_token) {
            $response | Add-Member -MemberType NoteProperty -Name "refresh_token" -Value $RefreshToken
        }
        
        # Add expiration timestamp
        $response | Add-Member -MemberType NoteProperty -Name "expires_at" -Value ([DateTimeOffset]::UtcNow.AddSeconds($response.expires_in).ToUnixTimeSeconds())
        
        return $response
        
    } catch {
        Write-Warning "Token refresh failed: $($_.Exception.Message)"
        return $null
    } finally {
        # Clear sensitive data
        if ($clientSecretPlain) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR([System.Runtime.InteropServices.Marshal]::StringToBSTR($clientSecretPlain))
        }
    }
}

function Get-CachedToken {
    param(
        [string]$TokenCachePath
    )
    
    try {
        if (Test-Path $TokenCachePath) {
            $tokenData = Get-Content $TokenCachePath | ConvertFrom-Json
            return $tokenData
        }
    } catch {
        Write-Warning "Failed to read cached token: $($_.Exception.Message)"
    }
    
    return $null
}

function Save-TokenCache {
    param(
        [object]$Token,
        [string]$TokenCachePath
    )
    
    try {
        $cacheDir = Split-Path $TokenCachePath -Parent
        if (-not (Test-Path $cacheDir)) {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        }
        
        $Token | ConvertTo-Json -Depth 5 | Out-File $TokenCachePath -Encoding UTF8
        
        # Set restrictive permissions on cache file
        if ($IsWindows -or $PSVersionTable.PSEdition -eq "Desktop") {
            $acl = Get-Acl $TokenCachePath
            $acl.SetAccessRuleProtection($true, $false)
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                "FullControl",
                "Allow"
            )
            $acl.SetAccessRule($accessRule)
            Set-Acl $TokenCachePath $acl
        } else {
            chmod 600 $TokenCachePath
        }
        
    } catch {
        Write-Warning "Failed to cache token: $($_.Exception.Message)"
    }
}

function Test-TokenValidity {
    param(
        [object]$Token
    )
    
    if (-not $Token -or -not $Token.access_token) {
        return $false
    }
    
    if ($Token.expires_at) {
        $expirationTime = [DateTimeOffset]::FromUnixTimeSeconds($Token.expires_at)
        $bufferTime = [TimeSpan]::FromMinutes(5) # 5 minute buffer
        
        return ($expirationTime - $bufferTime) -gt [DateTimeOffset]::UtcNow
    }
    
    # If no expiration info, assume token is still valid for a short time
    return $true
}

function Remove-TokenCache {
    <#
    .SYNOPSIS
        Removes cached tokens (useful for logout/cleanup)
    #>
    param(
        [string]$TokenCachePath = "$env:TEMP\google-forms-tokens.json"
    )
    
    try {
        if (Test-Path $TokenCachePath) {
            Remove-Item $TokenCachePath -Force
            Write-Verbose "Token cache cleared"
        }
    } catch {
        Write-Warning "Failed to remove token cache: $($_.Exception.Message)"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-GoogleFormsAccessToken',
    'Remove-TokenCache'
)
