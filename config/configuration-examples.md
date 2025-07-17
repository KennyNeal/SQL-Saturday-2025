# Configuration Settings

## Database Connection Strings

### Local Development
```powershell
$connectionString = "Server=localhost\SQLEXPRESS;Database=SQLSaturday;Integrated Security=SSPI;"
```

### Production  
```powershell
$connectionString = "Server=PROD-SQL-01;Database=SQLSaturday;Integrated Security=SSPI;"
```

## API Endpoints

### EventBrite
```powershell
$eventBriteApiUrl = "https://www.eventbriteapi.com/v3/events/YOUR_EVENT_ID/attendees/"
$eventBriteToken = Get-Secret -Name "EventBriteToken"  # Stored in secret management
```

### Sessionize
```powershell
$sessionizeApiUrl = "https://sessionize.com/api/v2/YOUR_EVENT_ID/view/GridSmart"
```

## Email Settings

### Gmail Configuration
```powershell
$smtpServer = "smtp.gmail.com"
$smtpPort = 587
$fromEmail = "yourevent@gmail.com"
$credentialPath = "config/gmail-credentials.xml"
```

### Production SMTP (Recommended)
```powershell
$smtpServer = "mail.yourdomain.com"
$smtpPort = 587
$fromEmail = "noreply@yourdomain.com"
```

## File Paths

### Base Paths
```powershell
$BaseFolder = "C:\SQL-Saturday-Event-Management"
$outputFolder = Join-Path $BaseFolder "output"
$assetsFolder = Join-Path $BaseFolder "assets"
```

### Specific Paths
```powershell
$sqlSatLogoPath = Join-Path $assetsFolder "images\SQL_2025.png"
$sponsorFolder = Join-Path $assetsFolder "images\Sponsor Logos\Raffle"
$speedPassOutput = Join-Path $outputFolder "speedpasses"
$scheduleOutput = Join-Path $outputFolder "schedules"
```

## Event-Specific Settings

### Event Details
```powershell
$eventName = "SQL Saturday Baton Rouge 2025"
$eventDate = "2025-03-15"
$eventLocation = "Louisiana State University"
$eventWebsite = "https://sqlsaturday.com/2025-03-15-sqlsaturday1234/"
```

### SpeedPass Settings
```powershell
$speedPassWidth = 400   # pixels
$speedPassHeight = 600  # pixels
$qrCodeSize = 100      # pixels
$includeSponsorLogos = $true
$maxSponsorsPerPass = 3
```

### Email Settings
```powershell
$emailBatchSize = 50        # emails per batch
$delayBetweenEmails = 2     # seconds
$delayBetweenBatches = 30   # seconds
$maxRetryAttempts = 3
```

## Secret Management Setup

### Initial Configuration
```powershell
# Run once to set up secret store
Set-SecretStoreConfiguration -Scope CurrentUser -Authentication Password

# Store secrets
Set-Secret -Name "EventBriteToken" -Secret "YOUR_EVENTBRITE_API_TOKEN"
Set-Secret -Name "SessionizeApiKey" -Secret "YOUR_SESSIONIZE_API_KEY"
```

### Retrieve Secrets
```powershell
$eventBriteToken = Get-Secret -Name "EventBriteToken" -AsPlainText
```

## Environment Variables

### PowerShell Profile Setup
Add to your PowerShell profile for easier script execution:

```powershell
# SQL Saturday Environment
$env:SQL_SATURDAY_BASE = "C:\SQL-Saturday-Event-Management"
$env:SQL_SATURDAY_DB = "Server=localhost\SQLEXPRESS;Database=SQLSaturday;Integrated Security=SSPI;"

# Helper functions
function Set-SQLSaturdayLocation {
    Set-Location $env:SQL_SATURDAY_BASE
}

Set-Alias -Name sqlsat -Value Set-SQLSaturdayLocation
```
