# Gmail Credentials Setup

The SQL Saturday email system now uses PowerShell SecretManagement for secure credential storage instead of encrypted XML files.

## Initial Setup

1. **Run the setup script** to configure Gmail credentials:
   ```powershell
   .\Setup-EmailCredentials.ps1
   ```

2. **Follow the prompts** to enter your Gmail email address and app password.

## Manual Setup (Alternative)

If you prefer to set up credentials manually:

```powershell
# Install required modules
Install-Module Microsoft.PowerShell.SecretManagement -Force
Install-Module Microsoft.PowerShell.SecretStore -Force

# Register the SecretStore vault
Register-SecretVault -Name SecretStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault

# Store Gmail credentials
Set-Secret -Name "SQLSaturday-Gmail" -Secret (Get-Credential)
```

## Usage

Once credentials are set up, use the mailing script normally:

```powershell
# Preview emails
.\Mailing.ps1 -WhatIf

# Send emails
.\Mailing.ps1

# Use custom secret name
.\Mailing.ps1 -SecretName "MyGmailSecret"
```

## Gmail App Password

⚠️ **Important**: You must use a Gmail App Password, not your regular password.

To create an App Password:
1. Go to [Google Account Security](https://myaccount.google.com/security)
2. Enable 2-Step Verification if not already enabled
3. Go to "App passwords" and generate a new one
4. Use that 16-character password in the credential setup

## Benefits

- **More secure**: No credential files on disk
- **Cross-platform**: Works on Windows, macOS, and Linux
- **Integrated**: Uses PowerShell's built-in secret management
- **Flexible**: Can use different secret names for different environments

## Troubleshooting

If you get credential errors:
1. Verify the secret exists: `Get-Secret -Name "SQLSaturday-Gmail"`
2. Re-run setup: `.\Setup-EmailCredentials.ps1`
3. Check SecretManagement: `Get-SecretVault`
