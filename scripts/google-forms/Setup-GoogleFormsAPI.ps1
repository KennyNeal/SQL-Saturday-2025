# Google Forms API Setup and Authentication Helper
# This script helps set up Google Cloud credentials for the Forms API

param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectId,
    
    [Parameter(Mandatory = $false)]
    [string]$CredentialsOutputPath = ".\config\google-credentials.json"
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

function Show-SetupInstructions {
    Write-Host @"

=== Google Forms API Setup Instructions ===

To use the Google Forms API, you need to:

1. Create or select a Google Cloud Project
   - Go to: https://console.cloud.google.com/
   - Create a new project or select an existing one
   - Note your Project ID

2. Enable the Google Forms API
   - Go to: https://console.cloud.google.com/apis/library
   - Search for "Google Forms API"
   - Click "Enable"

3. Create OAuth 2.0 Credentials
   - Go to: https://console.cloud.google.com/apis/credentials
   - Click "Create Credentials" > "OAuth 2.0 Client IDs"
   - Choose "Desktop application" as the application type
   - Name it "SQL Saturday Forms Generator"
   - Download the JSON file

4. Set up OAuth Consent Screen (if not already done)
   - Go to: https://console.cloud.google.com/apis/credentials/consent
   - Configure the consent screen with your app information
   - Add your email to test users during development

5. Configure Scopes
   - Your application will need the following scope:
     https://www.googleapis.com/auth/forms

6. Save the credentials file
   - Save the downloaded JSON file as: $CredentialsOutputPath
   - This file contains your client ID and client secret

7. Run the main script
   - Execute: .\Generate-SessionFeedbackForms.ps1 -CredentialsPath "$CredentialsOutputPath"

Important Security Notes:
- Keep your credentials file secure and never commit it to version control
- Use environment variables or Azure Key Vault in production
- Implement proper OAuth 2.0 flow with refresh tokens for production use
- Consider using service accounts for server-to-server communication

"@
}

function Test-GoogleCloudCLI {
    try {
        $gcloudVersion = gcloud version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Google Cloud CLI is installed"
            return $true
        }
    } catch {
        # gcloud not found
    }
    
    Write-Log "Google Cloud CLI not found. Install from: https://cloud.google.com/sdk/docs/install" "WARNING"
    return $false
}

function New-SampleCredentialsFile {
    $sampleCredentials = @{
        installed = @{
            client_id = "YOUR_CLIENT_ID.apps.googleusercontent.com"
            project_id = "your-project-id"
            auth_uri = "https://accounts.google.com/o/oauth2/auth"
            token_uri = "https://oauth2.googleapis.com/token"
            auth_provider_x509_cert_url = "https://www.googleapis.com/oauth2/v1/certs"
            client_secret = "YOUR_CLIENT_SECRET"
            redirect_uris = @("http://localhost")
        }
    }
    
    $credentialsDir = Split-Path $CredentialsOutputPath -Parent
    if (-not (Test-Path $credentialsDir)) {
        New-Item -ItemType Directory -Path $credentialsDir -Force | Out-Null
    }
    
    $samplePath = $CredentialsOutputPath -replace '\.json$', '-sample.json'
    $sampleCredentials | ConvertTo-Json -Depth 5 | Out-File $samplePath -Encoding UTF8
    
    Write-Log "Sample credentials file created: $samplePath"
    Write-Log "Replace the placeholder values with your actual Google Cloud credentials"
}

function Initialize-OAuth2Flow {
    param(
        [string]$CredentialsPath
    )
    
    if (-not (Test-Path $CredentialsPath)) {
        Write-Log "Credentials file not found: $CredentialsPath" "ERROR"
        return $false
    }
    
    try {
        $credentials = Get-Content $CredentialsPath | ConvertFrom-Json
        $clientId = $credentials.installed.client_id
        $clientSecret = $credentials.installed.client_secret
        
        if ($clientId -like "*YOUR_CLIENT_ID*" -or $clientSecret -like "*YOUR_CLIENT_SECRET*") {
            Write-Log "Please update the credentials file with your actual Google Cloud credentials" "ERROR"
            return $false
        }
        
        Write-Log "Credentials file appears valid"
        
        # OAuth 2.0 flow instructions
        Write-Host @"

=== OAuth 2.0 Authentication Flow ===

For production use, implement the following OAuth 2.0 flow:

1. Authorization URL:
   https://accounts.google.com/o/oauth2/auth?client_id=$clientId&redirect_uri=http://localhost&response_type=code&scope=https://www.googleapis.com/auth/forms

2. After user authorization, exchange the code for tokens:
   POST https://oauth2.googleapis.com/token
   {
     "client_id": "$clientId",
     "client_secret": "$clientSecret",
     "code": "AUTHORIZATION_CODE",
     "grant_type": "authorization_code",
     "redirect_uri": "http://localhost"
   }

3. Use the access_token for API calls
4. Use refresh_token to get new access tokens when they expire

"@
        
        return $true
        
    } catch {
        Write-Log "Error reading credentials file: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main execution
try {
    Write-Log "Google Forms API Setup Helper"
    
    # Check if Google Cloud CLI is available
    Test-GoogleCloudCLI | Out-Null
    
    # Show setup instructions
    Show-SetupInstructions
    
    # Create sample credentials file
    New-SampleCredentialsFile
    
    # If credentials file exists, validate it
    if (Test-Path $CredentialsOutputPath) {
        Initialize-OAuth2Flow -CredentialsPath $CredentialsOutputPath | Out-Null
    }
    
    Write-Log "Setup helper completed. Follow the instructions above to configure your Google Forms API access."
    
} catch {
    Write-Log "Setup failed: $($_.Exception.Message)" "ERROR"
    exit 1
}
