# SQL Saturday Event Management Workflow
# Processes new attendees: Import -> Generate SpeedPasses -> Send Emails

param(
    [switch]$WhatIf,
    [switch]$SkipImport,
    [switch]$SkipSpeedPasses,
    [switch]$SkipEmails
)

$scriptPath = $PSScriptRoot
$rootPath = Split-Path -Parent $scriptPath

Write-Host "SQL Saturday Event Management Workflow"
Write-Host "======================================"

if ($WhatIf) {
    Write-Host "WHATIF MODE: No changes will be made" -ForegroundColor Yellow
}

# Step 1: Import new attendees from EventBrite
if (-not $SkipImport) {
    Write-Host "`n1. Importing attendees from EventBrite..."
    
    $importScript = Join-Path $rootPath "scripts\attendee-management\Reload Attendees From EventBrite.ps1"
    if (Test-Path $importScript) {
        if ($WhatIf) {
            Write-Host "   Would run: $importScript"
        } else {
            & $importScript
            if ($LASTEXITCODE -ne 0) {
                Write-Host "ERROR: Attendee import failed!" -ForegroundColor Red
                exit 1
            }
        }
    } else {
        Write-Host "   WARNING: Import script not found at $importScript" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n1. Skipping attendee import"
}

# Step 2: Generate SpeedPasses for new attendees
if (-not $SkipSpeedPasses) {
    Write-Host "`n2. Generating SpeedPasses for new attendees..."
    
    $speedpassScript = Join-Path $rootPath "scripts\speedpass-generation\Generate-SpeedPasses.ps1"
    if (Test-Path $speedpassScript) {
        if ($WhatIf) {
            Write-Host "   Would run: $speedpassScript"
        } else {
            & $speedpassScript
            if ($LASTEXITCODE -ne 0) {
                Write-Host "ERROR: SpeedPass generation failed!" -ForegroundColor Red
                exit 1
            }
        }
    } else {
        Write-Host "   WARNING: SpeedPass script not found at $speedpassScript" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n2. Skipping SpeedPass generation"
}

# Step 3: Send emails to attendees who haven't been emailed yet
if (-not $SkipEmails) {
    Write-Host "`n3. Sending emails to new attendees..."
    
    $emailScript = Join-Path $rootPath "scripts\email-system\Mailing.ps1"
    if (Test-Path $emailScript) {
        if ($WhatIf) {
            Write-Host "   Would run: $emailScript -WhatIf"
            & $emailScript -WhatIf
        } else {
            & $emailScript
            if ($LASTEXITCODE -ne 0) {
                Write-Host "ERROR: Email sending failed!" -ForegroundColor Red
                exit 1
            }
        }
    } else {
        Write-Host "   WARNING: Email script not found at $emailScript" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n3. Skipping email sending"
}

Write-Host "`nWorkflow completed successfully!"
Write-Host "`nNext steps:"
Write-Host "- Check output folder for new SpeedPass files"
Write-Host "- Monitor email delivery status"
Write-Host "- Run backup: .\Simple-Backup.ps1"
