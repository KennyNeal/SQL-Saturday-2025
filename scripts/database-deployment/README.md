# Database Deployment Scripts

## Overview
Scripts for deploying and managing the SQL Server database schema and stored procedures.

## Scripts

### `Deploy-EmailStoredProcedures.ps1`
**Purpose**: Deploy stored procedures for email system functionality

**Features**:
- Creates required stored procedures for attendee management
- Handles database schema updates
- Idempotent deployment (safe to run multiple times)
- Validation of deployment success

**Usage**:
```powershell
.\Deploy-EmailStoredProcedures.ps1
```

## Stored Procedures Deployed

### `AttendeesGetForEmail`
**Purpose**: Retrieve attendees who need to receive emails
- Returns unprocessed attendees with valid email addresses
- Excludes already emailed attendees
- Filters out incomplete records
- Orders by last name, first name

### `AttendeesMarkAsEmailed`  
**Purpose**: Mark single attendee as having received email
- **Parameters**: `@Barcode` (attendee identifier)
- Updates email tracking table
- Prevents duplicate email sends

### `AttendeesMarkBatchAsEmailed`
**Purpose**: Mark multiple attendees as emailed (batch operation)
- **Parameters**: `@BarcodeList` (comma-separated list)
- Efficient bulk update operation
- Transaction safety for consistency

## Database Schema

### Core Tables
- **`Attendees`**: Main attendee registration data
- **`AttendeesPrinted`**: Tracks SpeedPass generation status
- **`AttendeesEmailed`**: Tracks email delivery status

### Table Relationships
```sql
Attendees (1) --> (0..1) AttendeesPrinted
Attendees (1) --> (0..1) AttendeesEmailed
```

## Deployment Process

### Prerequisites
- SQL Server instance running
- Database `SQLSaturday` exists
- Sufficient permissions for schema changes

### Validation Steps
1. **Connection Test**: Verify database connectivity
2. **Procedure Creation**: Deploy each stored procedure
3. **Permission Grant**: Ensure execute permissions
4. **Functionality Test**: Basic procedure execution

### Error Handling
- Detailed error logging for failed deployments
- Rollback capability for partial failures
- Validation of each procedure creation

## Manual Database Setup

If automated deployment fails, you can manually create the required objects:

### Create Database
```sql
CREATE DATABASE SQLSaturday;
USE SQLSaturday;
```

### Create Tables (if not exist from EventBrite import)
```sql
-- See database project files for complete schema
-- Located in: database/DatabaseProjectSQLSaturday/
```

### Verify Deployment
```sql
-- Check stored procedures exist
SELECT name FROM sys.procedures 
WHERE name LIKE 'Attendees%';

-- Test basic functionality
EXEC AttendeesGetForEmail;
```

## Maintenance

### Regular Tasks
- Monitor procedure performance
- Update statistics on attendee tables
- Archive old event data
- Backup database regularly

### Troubleshooting
- Check SQL Server error logs
- Verify database permissions
- Test stored procedure execution
- Monitor database space usage
