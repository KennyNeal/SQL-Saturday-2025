<#
.SYNOPSIS
Helper script to set up Gmail credentials in PowerShell SecretManagement for SQL Saturday email system.

.DESCRIPTION
This script helps configure Gmail app password credentials in PowerShell SecretManagement.
It will prompt for Gmail username and app password, then store them securely.

.PARAMETER SecretName
Name of the secret to create. Defaults to 'SQLSaturday-Gmail'.

.EXAMPLE
.\Setup-EmailCredentials.ps1
Set up Gmail credentials with default secret name.

.EXAMPLE
.\Setup-EmailCredentials.ps1 -SecretName "MyGmailSecret"
Set up Gmail credentials with custom secret name.

.NOTES
Requires PowerShell SecretManagement module.
Gmail app password must be generated from Gmail account settings.
#>

param(
    [string]$SecretName = "SQLSaturday-Gmail"
)

# Check if SecretManagement module is available
if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement)) {
    Write-Host "Installing Microsoft.PowerShell.SecretManagement module..." -ForegroundColor Yellow
    Install-Module -Name Microsoft.PowerShell.SecretManagement -Force -AllowClobber
}

# Check if SecretStore module is available
if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretStore)) {
    Write-Host "Installing Microsoft.PowerShell.SecretStore module..." -ForegroundColor Yellow
    Install-Module -Name Microsoft.PowerShell.SecretStore -Force -AllowClobber
}

# Import modules
Import-Module Microsoft.PowerShell.SecretManagement
Import-Module Microsoft.PowerShell.SecretStore

# Check if SecretStore vault is registered
$vaults = Get-SecretVault
if (-not ($vaults | Where-Object { $_.Name -eq "SecretStore" })) {
    Write-Host "Registering SecretStore vault..." -ForegroundColor Yellow
    Register-SecretVault -Name SecretStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
}

Write-Host "=== Gmail Credentials Setup for SQL Saturday ===" -ForegroundColor Green
Write-Host ""
Write-Host "This script will help you set up Gmail credentials for the SQL Saturday email system."
Write-Host "You will need:"
Write-Host "1. Your Gmail email address"
Write-Host "2. A Gmail App Password (not your regular password)"
Write-Host ""
Write-Host "To create a Gmail App Password:"
Write-Host "1. Go to https://myaccount.google.com/security"
Write-Host "2. Enable 2-Step Verification if not already enabled"
Write-Host "3. Go to 'App passwords' and generate a new one"
Write-Host "4. Use that 16-character password below"
Write-Host ""

# Get credentials from user
$credential = Get-Credential -Message "Enter your Gmail email address and App Password"

if ($credential) {
    try {
        # Store the credential
        Set-Secret -Name $SecretName -Secret $credential -Vault SecretStore
        Write-Host "✓ Gmail credentials stored successfully as '$SecretName'" -ForegroundColor Green
        
        # Test retrieval
        $testCred = Get-Secret -Name $SecretName -AsPlainText:$false
        Write-Host "✓ Credentials verified - stored for user: $($testCred.UserName)" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "Setup complete! You can now use the Mailing.ps1 script." -ForegroundColor Green
        Write-Host "Example: .\Mailing.ps1 -WhatIf" -ForegroundColor Cyan
        
    } catch {
        Write-Host "✗ Error storing credentials: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please try again or check your SecretManagement setup." -ForegroundColor Yellow
    }
} else {
    Write-Host "✗ No credentials provided. Setup cancelled." -ForegroundColor Yellow
}
