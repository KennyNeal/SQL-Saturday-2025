# Convert Session Data for Google Apps Script
# This script converts sessions.json into JavaScript array format for Apps Script

param(
    [Parameter(Mandatory = $false)]
    [string]$SessionDataPath = ".\sessions.json",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\output\sessions-for-apps-script.js"
)

Write-Host "🔄 Converting session data for Google Apps Script..." -ForegroundColor Green

try {
    # Load session data
    if (-not (Test-Path $SessionDataPath)) {
        throw "Session data file not found: $SessionDataPath"
    }
    
    $sessionsData = Get-Content $SessionDataPath | ConvertFrom-Json
    Write-Host "✓ Loaded session data" -ForegroundColor Green
    
    # Filter and convert sessions
    $validSessions = @()
    
    foreach ($session in $sessionsData.sessions) {
        # Skip service sessions and non-feedback sessions
        if ($session.isServiceSession -or 
            $session.title -match "Lunch|Break|Registration|Keynote|Welcome|Closing" -or
            $session.roomId -eq 20946 -or $session.roomId -eq 20947) {
            continue
        }
        
        # Create simplified session object
        $sessionObj = @{
            title = $session.title
            speakers = @($session.speakers | ForEach-Object { @{ name = $_.name } })
            room = $session.room
            startsAt = $session.startsAt
        }
        
        $validSessions += $sessionObj
    }
    
    Write-Host "✓ Filtered to $($validSessions.Count) valid sessions" -ForegroundColor Green
    
    # Create output directory
    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Generate JavaScript function
    $jsContent = @"
function getSessionData() {
  return [
"@
    
    foreach ($session in $validSessions) {
        $speakersJs = ($session.speakers | ForEach-Object { "{name: `"$($_.name -replace '"', '\"')`"}" }) -join ", "
        $titleJs = $session.title -replace '"', '\"' -replace "`n", " " -replace "`r", ""
        $roomJs = $session.room -replace '"', '\"'
        
        $jsContent += @"

    {
      title: "$titleJs",
      speakers: [$speakersJs],
      room: "$roomJs",
      startsAt: "$($session.startsAt)"
    },
"@
    }
    
    # Remove trailing comma and close
    $jsContent = $jsContent.TrimEnd(',')
    $jsContent += @"

  ];
}
"@
    
    # Save the JavaScript file
    $jsContent | Set-Content $OutputPath -Encoding UTF8
    Write-Host "✓ JavaScript data saved to: $OutputPath" -ForegroundColor Green
    
    # Also create a simple CSV for manual use
    $csvPath = $OutputPath -replace '\.js$', '.csv'
    $csvData = $validSessions | ForEach-Object {
        [PSCustomObject]@{
            Title = $_.title
            Speaker = ($_.speakers | ForEach-Object { $_.name }) -join ", "
            Room = $_.room
            StartTime = $_.startsAt
        }
    }
    
    $csvData | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "✓ CSV data saved to: $csvPath" -ForegroundColor Green
    
    Write-Host "`n🎉 Conversion completed!" -ForegroundColor Green
    Write-Host "📁 JavaScript file: $OutputPath" -ForegroundColor Cyan
    Write-Host "📁 CSV file: $csvPath" -ForegroundColor Cyan
    Write-Host "`n📋 Next steps:" -ForegroundColor Yellow
    Write-Host "1. Copy the content of $OutputPath into your Google Apps Script" -ForegroundColor White
    Write-Host "2. Replace the getSessionData() function in the Apps Script" -ForegroundColor White
    Write-Host "3. Run the createSessionFeedbackForms() function" -ForegroundColor White
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
