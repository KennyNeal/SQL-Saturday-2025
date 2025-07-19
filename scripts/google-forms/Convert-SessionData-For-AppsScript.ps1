# Convert Session Data for Google Apps Script
# This script converts sessions.json into JavaScript array format for Apps Script
# NOTE: The current Google Apps Script already has manual session data built-in,
# so this script is mainly useful for updating the data or creating new versions.

param(
    [Parameter(Mandatory = $false)]
    [string]$SessionDataPath = ".\sessions.json",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\output\sessions-for-apps-script.js",
    
    [Parameter(Mandatory = $false)]
    [switch]$UpdateAppsScript = $false
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
    
    # Generate JavaScript function for Apps Script manual fallback
    $jsContent = @"
/**
 * Manual session data fallback (in case API access is blocked)
 * This replaces the getManualSessionData() function in Google Apps Script
 */
function getManualSessionData() {
  console.log('📋 Using manual session data...');
  
  // Complete session data for SQL Saturday 2025
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
    Write-Host "1. Copy the content of $OutputPath" -ForegroundColor White
    Write-Host "2. In Google Apps Script, replace the getManualSessionData() function" -ForegroundColor White
    Write-Host "3. Run getSessionCount() to verify $($validSessions.Count) sessions are detected" -ForegroundColor White
    Write-Host "4. Run createSessionFeedbackForms() to generate all forms" -ForegroundColor White
    
    if ($UpdateAppsScript) {
        Write-Host "`n🔄 Updating Google Apps Script file..." -ForegroundColor Cyan
        $appsScriptPath = ".\Google-Apps-Script-Complete.js"
        if (Test-Path $appsScriptPath) {
            # Read the current Apps Script file
            $appsScriptContent = Get-Content $appsScriptPath -Raw
            
            # Extract just the session data array from our generated JavaScript
            $sessionDataOnly = $jsContent -replace '.*return \[', '' -replace '\];.*', ''
            
            # Update the getManualSessionData function in the Apps Script
            $updatedContent = $appsScriptContent -replace '(function getManualSessionData\(\) \{[^}]*return \[)[^]]*(\];[^}]*\})', "`$1$sessionDataOnly`$2"
            
            # Save the updated file
            $updatedContent | Set-Content $appsScriptPath -Encoding UTF8
            Write-Host "✓ Updated Google Apps Script with new session data" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Google Apps Script file not found at $appsScriptPath" -ForegroundColor Yellow
        }
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
