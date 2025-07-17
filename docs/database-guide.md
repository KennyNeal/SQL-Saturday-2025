# SQL Saturday Email System - Database Documentation

## Overview
The email system now uses stored procedures to manage attendee data and email tracking, providing better separation of concerns and improved maintainability.

## New Stored Procedures

### 1. `AttendeesGetForEmail`
**Purpose**: Retrieves attendees who haven't been emailed yet and have valid email addresses.

**Returns**:
- `Barcode` - Unique identifier for the attendee
- `First_Name` - Attendee's first name
- `Last_Name` - Attendee's last name  
- `Email` - Email address
- `Order_Date` - When they registered
- `Job_Title` - Professional title
- `Company` - Company name

**Logic**: 
- Excludes attendees already in `AttendeesPrinted` table
- Filters out NULL/empty email addresses
- Filters out NULL first/last names
- Orders by last name, first name

### 2. `AttendeesMarkAsEmailed`
**Purpose**: Marks a single attendee as having been emailed.

**Parameters**:
- `@Barcode` (NVARCHAR(50)) - The attendee's barcode
- `@EmailSentDateTime` (DATETIME2(3), optional) - When the email was sent (defaults to current time)

**Returns**: Status message indicating success or if already existed

**Logic**:
- Inserts new record if barcode doesn't exist
- Updates timestamp if record already exists
- Returns informational message about the action taken

### 3. `AttendeesMarkBatchAsEmailed`
**Purpose**: Efficiently marks multiple attendees as emailed in a single operation.

**Parameters**:
- `@BarcodeList` (NVARCHAR(MAX)) - Comma-separated list of barcodes
- `@EmailSentDateTime` (DATETIME2(3), optional) - When emails were sent (defaults to current time)

**Returns**: 
- `Result` - Status (SUCCESS)
- `NewRecords` - Count of new records inserted
- `UpdatedRecords` - Count of existing records updated  
- `TotalProcessed` - Total number processed
- `Message` - Summary message

**Logic**:
- Splits comma-separated barcode list into temp table
- Inserts new records for barcodes not in `AttendeesPrinted`
- Updates existing records with new timestamp
- Returns comprehensive statistics

## Updated PowerShell Script Features

### New Configuration Variables
```powershell
$getAttendeesQuery = "EXEC dbo.AttendeesGetForEmail"
$markEmailedProc = "dbo.AttendeesMarkAsEmailed"  
$markBatchEmailedProc = "dbo.AttendeesMarkBatchAsEmailed"
```

### Enhanced Attendee Data
The script now captures additional attendee information:
- Order Date
- Job Title  
- Company

### Improved Database Logging
- **Batch Processing**: Database updates are batched per email batch for better performance
- **Error Isolation**: Email sending errors don't prevent database logging for successful sends
- **Better Feedback**: Clear status messages about database operations

### New Helper Functions
- `Set-AttendeeAsEmailed`: Marks individual attendee (for fallback scenarios)
- `Set-BatchAttendeesAsEmailed`: Efficiently processes multiple attendees

## Deployment Instructions

### 1. Deploy Stored Procedures
```powershell
# Preview what will be deployed
.\Deploy-EmailStoredProcedures.ps1 -WhatIf

# Deploy to default database
.\Deploy-EmailStoredProcedures.ps1

# Deploy to custom database
.\Deploy-EmailStoredProcedures.ps1 -ConnectionString "Server=myserver;Database=mydb;..."
```

### 2. Test the System
```powershell
# Preview emails without sending
.\Mailing.ps1 -WhatIf

# Send emails with default settings
.\Mailing.ps1
```

## Benefits of the New Approach

### 🛡️ **Security & Reliability**
- Parameterized queries prevent SQL injection
- Stored procedures provide consistent data access
- Better error handling and transaction management

### ⚡ **Performance** 
- Batch database updates reduce connection overhead
- Optimized queries in stored procedures
- Reduced network traffic

### 🔧 **Maintainability**
- Database logic separated from PowerShell script
- Easier to modify queries without touching PowerShell
- Consistent data access patterns

### 📊 **Observability**
- Clear status reporting from database operations
- Better tracking of email sending progress
- Comprehensive logging and error reporting

## Database Schema Notes

The `AttendeesPrinted` table uses:
- `Barcode` as primary key (NVARCHAR(50))
- `CreatedDatetime` (DATETIME2(3)) with default of GETDATE()

This allows for:
- Duplicate protection (can't email same attendee twice accidentally)
- Audit trail of when emails were sent
- Easy queries to find who has/hasn't been emailed

## Troubleshooting

### Common Issues
1. **"Stored procedure not found"** - Run the deployment script
2. **"Parameter count mismatch"** - Check stored procedure parameter names
3. **"Batch update failed"** - Check for special characters in barcodes

### Verification Queries
```sql
-- Check if procedures exist
SELECT name FROM sys.procedures WHERE name LIKE 'Attendees%Email%'

-- See who's been emailed
SELECT COUNT(*) as EmailedCount FROM AttendeesPrinted

-- Check recent email activity  
SELECT TOP 10 * FROM AttendeesPrinted ORDER BY CreatedDatetime DESC
```
