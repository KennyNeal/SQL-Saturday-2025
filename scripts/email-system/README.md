# Email System Scripts

## Overview
Scripts for sending SpeedPasses and event communications to attendees.

## Scripts

### `Mailing.ps1`
**Purpose**: Send SpeedPass PDFs and volunteer notifications via email

**Features**:
- Sends personalized emails with SpeedPass attachments
- Supports attendee and volunteer email types
- Batch processing with configurable delays
- WhatIf mode for testing
- Email delivery tracking in database
- Error handling and retry logic

**Usage**:
```powershell
# Preview emails without sending
.\Mailing.ps1 -WhatIf

# Send attendee emails with SpeedPasses
.\Mailing.ps1 -EmailType attendee

# Send volunteer recruitment emails  
.\Mailing.ps1 -EmailType volunteer

# Send with warning banner (for resends)
.\Mailing.ps1 -ShowBanner

# Test with single email address
.\Mailing.ps1 -TestEmail "test@example.com"
```

**Parameters**:
- `-WhatIf`: Preview mode, no emails sent
- `-ShowBanner`: Include warning banner for resends
- `-EmailType`: 'attendee' or 'volunteer' (default: attendee)
- `-TestEmail`: Send only to specified email address
- `-DelaySeconds`: Delay between emails (default: 2)
- `-BatchSize`: Emails per batch (default: 50)

## Email Templates

### Attendee Template
- Personalized greeting
- SpeedPass attachment instructions
- Pre-conference session information
- Volunteer recruitment call-to-action
- Social media sharing request

### Volunteer Template
- Thank you for volunteering
- Link to volunteer signup system
- Event details and expectations

## Configuration

### Required Setup
1. **Gmail Credentials**: Stored in encrypted XML file
2. **Database Connection**: SQL Server with attendee data
3. **PDF Files**: SpeedPasses must be generated first

### Email Delivery Tracking
- Marks attendees as emailed in database
- Prevents duplicate emails
- Logs delivery errors and skipped emails

## Error Handling
- Creates error logs for failed deliveries
- Generates skipped email lists
- Handles attachment missing scenarios
- Graceful SMTP error recovery
