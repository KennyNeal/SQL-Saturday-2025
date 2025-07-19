# Download and cache session data from Sessionize API
# This script fetches the latest session data and saves it locally

param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\sessions.json",
    
    [Parameter(Mandatory = $false)]
    [string]$SessionizeApiUrl = "https://sessionize.com/api/v2/ta7h58rh/view/Sessions"
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

try {
    Write-Log "Downloading session data from Sessionize API..."
    Write-Log "API URL: $SessionizeApiUrl"
    
    # Fetch session data
    $sessionData = Invoke-RestMethod -Uri $SessionizeApiUrl -Method Get
    
    Write-Log "Successfully retrieved session data"
    
    # Count sessions
    $totalSessions = 0
    $roomCount = 0
    foreach ($room in $sessionData) {
        $roomCount++
        $sessionCount = ($room.sessions | Where-Object { -not $_.isServiceSession }).Count
        $totalSessions += $sessionCount
        Write-Log "Room '$($room.groupName)': $sessionCount sessions"
    }
    
    Write-Log "Total: $totalSessions sessions across $roomCount rooms"
    
    # Save to file
    $outputDir = Split-Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $sessionData | ConvertTo-Json -Depth 10 | Out-File $OutputPath -Encoding UTF8
    
    Write-Log "Session data saved to: $OutputPath"
    
    # Display sample of sessions
    Write-Log "Sample sessions:"
    $sampleSessions = $sessionData | ForEach-Object { $_.sessions } | Where-Object { -not $_.isServiceSession } | Select-Object -First 5
    foreach ($session in $sampleSessions) {
        $speakers = ($session.speakers | ForEach-Object { $_.name }) -join ", "
        $startTime = [DateTime]::Parse($session.startsAt).ToString("MM/dd HH:mm")
        Write-Log "  - $($session.title) ($speakers) at $startTime"
    }
    
    Write-Log "Session data download completed successfully!"
    
} catch {
    Write-Log "Failed to download session data: $($_.Exception.Message)" "ERROR"
    exit 1
}
