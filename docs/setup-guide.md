# Setup Guide

## Prerequisites

### PowerShell Modules
```powershell
# Install required modules
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser
```

### SQL Server
- SQL Server Express or full version
- Default instance: `localhost\SQLEXPRESS`
- Integrated Security enabled

### API Access
- **EventBrite API Token**: Required for attendee import
- **Sessionize API URL**: Required for schedule generation  
- **Gmail App Password**: Required for email sending

## Initial Setup

### 1. Configure Secret Management
```powershell
# Set up secret store (first time only)
Set-SecretStoreConfiguration -Scope CurrentUser -Authentication Password

# Store EventBrite API token
Set-Secret -Name "EventBriteToken" -Secret "YOUR_EVENTBRITE_TOKEN"

# Store Gmail credentials
$gmailCred = Get-Credential  # Enter Gmail address and app password
$gmailCred | Export-Clixml -Path "config/gmail-credentials.xml"
```

### 2. Database Setup
```powershell
# Deploy database schema and stored procedures
.\scripts\database-deployment\Deploy-EmailStoredProcedures.ps1
```

### 3. Configure Scripts
Update connection strings and paths in script files to match your environment.

## Workflow

### Import Attendees
```powershell
.\scripts\attendee-management\Reload-Attendees-From-EventBrite.ps1
```

### Generate SpeedPasses
```powershell
.\scripts\speedpass-generation\Generate-SpeedPasses.ps1
```

### Send Emails
```powershell
# Preview emails (no sending)
.\scripts\email-system\Mailing.ps1 -WhatIf

# Send emails
.\scripts\email-system\Mailing.ps1
```

### Generate Schedules
```powershell
.\scripts\schedule-management\Generate-Schedule.ps1 -ApiUrl "YOUR_SESSIONIZE_API_URL"
```

## Troubleshooting

### Common Issues
- **Secret not found**: Re-run secret setup commands
- **Database connection errors**: Verify SQL Server is running and connection string is correct
- **Email sending failures**: Check Gmail app password and firewall settings

### Log Files
- Email logs: `output/email-logs/`
- SpeedPass generation logs: `output/speedpass-logs/`
