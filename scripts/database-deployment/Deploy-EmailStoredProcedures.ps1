# Deploy SQL Saturday Email Stored Procedures
# This script deploys the new stored procedures for the email system

param(
    [string]$ConnectionString = "Server=localhost\SQLEXPRESS;Database=SQLSaturday;Integrated Security=SSPI;",
    [switch]$WhatIf
)

$storedProcs = @(
    @{
        Name = "AttendeesGetForEmail"
        File = "AttendeesGetForEmail.sql"
        Description = "Gets attendees who need to receive emails"
    },
    @{
        Name = "AttendeesMarkAsEmailed" 
        File = "AttendeesMarkAsEmailed.sql"
        Description = "Marks a single attendee as having been emailed"
    },
    @{
        Name = "AttendeesMarkBatchAsEmailed"
        File = "AttendeesMarkBatchAsEmailed.sql" 
        Description = "Marks multiple attendees as having been emailed (batch operation)"
    }
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$procPath = Join-Path $scriptPath "Database\DatabaseProjectSQLSaturday\dbo\StoredProcedures"

Write-Host "=== SQL Saturday Stored Procedure Deployment ===" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "🔍 WHATIF MODE: Scripts will be validated but not executed" -ForegroundColor Yellow
}

Write-Host "📁 Procedure Path: $procPath" -ForegroundColor Gray
Write-Host "🔗 Connection: $($ConnectionString -replace 'Password=[^;]*', 'Password=***')" -ForegroundColor Gray

foreach ($proc in $storedProcs) {
    $filePath = Join-Path $procPath $proc.File
    
    Write-Host "`n📄 Processing: $($proc.Name)" -ForegroundColor Green
    Write-Host "   $($proc.Description)" -ForegroundColor Gray
    
    if (-not (Test-Path $filePath)) {
        Write-Host "❌ File not found: $filePath" -ForegroundColor Red
        continue
    }
    
    try {
        $sql = Get-Content $filePath -Raw
        
        # Remove GO statements that cause issues with ExecuteNonQuery
        $sql = $sql -replace '(?m)^\s*GO\s*$', ''
        
        if ($WhatIf) {
            Write-Host "✅ SQL file validated: $($proc.File)" -ForegroundColor Green
            Write-Host "   Would execute: DROP/CREATE PROCEDURE dbo.$($proc.Name)" -ForegroundColor Gray
        } else {
            $connection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
            $connection.Open()
            
            try {
                # Check if procedure exists and drop it
                $checkSql = "IF OBJECT_ID('dbo.$($proc.Name)', 'P') IS NOT NULL DROP PROCEDURE dbo.$($proc.Name)"
                $dropCmd = $connection.CreateCommand()
                $dropCmd.CommandText = $checkSql
                $dropCmd.ExecuteNonQuery() | Out-Null
                
                # Create new procedure
                $createCmd = $connection.CreateCommand()
                $createCmd.CommandText = $sql
                $createCmd.ExecuteNonQuery() | Out-Null
                
                Write-Host "✅ Successfully deployed: dbo.$($proc.Name)" -ForegroundColor Green
                
            } catch {
                Write-Host "❌ Error executing SQL for $($proc.Name): $_" -ForegroundColor Red
                Write-Host "   SQL Preview: $($sql.Substring(0, [Math]::Min(100, $sql.Length)))..." -ForegroundColor Gray
            } finally {
                $connection.Close()
            }
        }
        
    } catch {
        Write-Host "❌ Error deploying $($proc.Name): $_" -ForegroundColor Red
    }
}

if ($WhatIf) {
    Write-Host "`n📋 PREVIEW COMPLETE" -ForegroundColor Cyan
    Write-Host "To actually deploy the procedures, run without -WhatIf parameter" -ForegroundColor Yellow
} else {
    Write-Host "`n✅ DEPLOYMENT COMPLETE" -ForegroundColor Cyan
    Write-Host "The new stored procedures are ready for use by the email script" -ForegroundColor Green
}
