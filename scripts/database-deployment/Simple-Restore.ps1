# Simple SQLSaturday Database Restore from OneDrive
# Restores the SQLSaturday database from a backup file

param(
    [Parameter(Mandatory=$true)]
    [string]$BackupFile,
    [string]$DatabaseName = "SQLSaturday"
)

Write-Host "Restoring $DatabaseName from $BackupFile..."

# Restore database using sqlcmd
$restoreSQL = @"
RESTORE DATABASE [$DatabaseName] 
FROM DISK = '$BackupFile' 
WITH REPLACE
"@

sqlcmd -S localhost\SQLEXPRESS -E -Q $restoreSQL

if ($LASTEXITCODE -eq 0) {
    Write-Host "Restore completed successfully!"
    Write-Host "Next step: Run .\Deploy-EmailStoredProcedures.ps1"
} else {
    Write-Host "ERROR: Restore failed!" -ForegroundColor Red
    exit 1
}
