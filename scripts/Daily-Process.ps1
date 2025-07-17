# Daily Attendee Processing
# Simple workflow to process new attendees

param([switch]$WhatIf)

Write-Host "Processing new attendees..."

# Step 1: Import from EventBrite
Write-Host "Importing from EventBrite..."
if ($WhatIf) {
    Write-Host "  Would run attendee import"
} else {
    & ".\attendee-management\Reload Attendees From EventBrite.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Import failed!" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Generate SpeedPasses
Write-Host "Generating SpeedPasses..."
if ($WhatIf) {
    Write-Host "  Would generate SpeedPasses"
} else {
    & ".\speedpass-generation\Generate-SpeedPasses.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: SpeedPass generation failed!" -ForegroundColor Red
        exit 1
    }
}

# Step 3: Send emails
Write-Host "Sending emails..."
if ($WhatIf) {
    Write-Host "  Would send emails"
    & ".\email-system\Mailing.ps1" -WhatIf
} else {
    & ".\email-system\Mailing.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Email sending failed!" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Processing completed!"
Write-Host "Next: Run database backup if needed"
