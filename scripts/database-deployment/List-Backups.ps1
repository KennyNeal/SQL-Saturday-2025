# List SQLSaturday backups in OneDrive
param(
    [string]$OneDrivePath = "$env:OneDrive\SQL-Saturday-Backups"
)

if (-not (Test-Path $OneDrivePath)) {
    Write-Host "No backups found in $OneDrivePath"
    exit 0
}

$backups = Get-ChildItem -Path $OneDrivePath -Filter "*.bak" | Sort-Object CreationTime -Descending

Write-Host "SQLSaturday Database Backups:"
foreach ($backup in $backups) {
    $size = [math]::Round($backup.Length / 1MB, 1)
    Write-Host "  $($backup.Name) - $($backup.CreationTime.ToString('yyyy-MM-dd HH:mm')) - $size MB"
}

if ($backups.Count -gt 0) {
    Write-Host "`nTo restore latest backup:"
    Write-Host "  .\Simple-Restore.ps1 -BackupFile '$($backups[0].FullName)'"
}
