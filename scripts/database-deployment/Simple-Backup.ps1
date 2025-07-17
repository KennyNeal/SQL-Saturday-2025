# Simple SQLSaturday Database Backup to OneDrive
# Creates a backup of the SQLSaturday database and saves it to OneDrive

param(
    [string]$OneDrivePath = "$env:OneDrive\SQL-Saturday-Backups"
)

$backupName = "SQLSaturday_$(Get-Date -Format 'yyyy-MM-dd_HHmm')"
$tempBackup = "C:\temp\$backupName.bak"
$finalBackup = "$OneDrivePath\$backupName.bak"

# Create directories if needed
New-Item -ItemType Directory -Path "C:\temp" -Force -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Path $OneDrivePath -Force -ErrorAction SilentlyContinue | Out-Null

Write-Host "Backing up SQLSaturday database..."

# Create backup using sqlcmd
$backupSQL = "BACKUP DATABASE SQLSaturday TO DISK = '$tempBackup' WITH FORMAT, CHECKSUM"
sqlcmd -S localhost\SQLEXPRESS -E -Q $backupSQL

if ($LASTEXITCODE -eq 0) {
    # Copy to OneDrive
    Copy-Item $tempBackup $finalBackup -Force
    Remove-Item $tempBackup -Force
    
    $size = [math]::Round((Get-Item $finalBackup).Length / 1MB, 1)
    Write-Host "Backup completed successfully!"
    Write-Host "Location: $finalBackup"
    Write-Host "Size: $size MB"
} else {
    Write-Host "ERROR: Backup failed!" -ForegroundColor Red
    exit 1
}
