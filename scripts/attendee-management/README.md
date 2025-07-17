# Attendee Management Scripts

## Overview
Scripts for importing and managing attendee data from EventBrite.

## Scripts

### `Reload-Attendees-From-EventBrite.ps1`
**Purpose**: Import attendee registration data from EventBrite API

**Features**:
- Securely fetches data using PowerShell SecretManagement
- Updates existing attendee records
- Handles registration changes and cancellations
- Logs import statistics

**Usage**:
```powershell
.\Reload-Attendees-From-EventBrite.ps1
```

**Requirements**:
- EventBrite API token stored in secret management
- SQL Server database with attendee tables
- Network access to EventBrite API

## Database Tables Used
- `Attendees` - Main attendee data
- `AttendeesPrinted` - Tracks SpeedPass generation status
- `AttendeesEmailed` - Tracks email delivery status

## Configuration
Update these variables in the script:
- `$connectionString` - Database connection
- `$eventId` - EventBrite event ID
- `$apiEndpoint` - EventBrite API URL
