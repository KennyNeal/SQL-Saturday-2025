# Debug Session Title Matching
# Compare session titles between Google Apps Script and sessions.json

Write-Host "🔍 Debugging session title matching..." -ForegroundColor Green

try {
    # Load sessions.json (new format)
    $sessionsData = Get-Content ".\sessions.json" | ConvertFrom-Json
    
    # Extract all sessions from the grouped structure
    $allSessions = @()
    foreach ($group in $sessionsData) {
        foreach ($session in $group.sessions) {
            # Add room information from group
            $session | Add-Member -NotePropertyName "room" -NotePropertyValue $group.groupName -Force
            $allSessions += $session
        }
    }
    
    # Filter to valid sessions (same logic as website generator)
    $validSessions = @()
    foreach ($session in $allSessions) {
        if ($session.isServiceSession -or 
            ($session.title -match "Lunch|Break|Registration|Keynote|Welcome|Closing") -or
            $session.roomId -eq 20946 -or $session.roomId -eq 20947) {
            continue
        }
        $validSessions += $session
    }
    
    Write-Host "✓ Found $($validSessions.Count) valid sessions in sessions.json" -ForegroundColor Green
    
    # Get Apps Script session titles
    $appsScriptContent = Get-Content ".\Google-Apps-Script-Complete.js" -Raw
    
    # Extract session titles from the Apps Script manual data
    $appsScriptTitles = @()
    if ($appsScriptContent -match 'return \[(.*?)\];' -and $matches[1]) {
        $sessionData = $matches[1]
        $titleMatches = [regex]::Matches($sessionData, 'title:\s*"([^"]*)"')
        foreach ($match in $titleMatches) {
            $appsScriptTitles += $match.Groups[1].Value
        }
    }
    
    Write-Host "✓ Found $($appsScriptTitles.Count) sessions in Apps Script" -ForegroundColor Green
    
    # Compare titles
    Write-Host "`n📊 Comparing session titles..." -ForegroundColor Cyan
    
    $jsonTitles = $validSessions | ForEach-Object { $_.title }
    $missingInAppsScript = $jsonTitles | Where-Object { $_ -notin $appsScriptTitles }
    $missingInJson = $appsScriptTitles | Where-Object { $_ -notin $jsonTitles }
    
    if ($missingInAppsScript.Count -gt 0) {
        Write-Host "`n❌ Sessions in JSON but NOT in Apps Script:" -ForegroundColor Red
        $missingInAppsScript | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
    }
    
    if ($missingInJson.Count -gt 0) {
        Write-Host "`n❌ Sessions in Apps Script but NOT in JSON:" -ForegroundColor Red
        $missingInJson | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
    }
    
    if ($missingInAppsScript.Count -eq 0 -and $missingInJson.Count -eq 0) {
        Write-Host "`n✅ All session titles match perfectly!" -ForegroundColor Green
    }
    
    # Show some examples for debugging
    Write-Host "`n📝 Sample titles from JSON:" -ForegroundColor Cyan
    $jsonTitles[0..4] | ForEach-Object { Write-Host "   - $_" }
    
    Write-Host "`n📝 Sample titles from Apps Script:" -ForegroundColor Cyan
    $appsScriptTitles[0..4] | ForEach-Object { Write-Host "   - $_" }
    
    # Check for character encoding issues
    Write-Host "`n🔤 Checking for special character issues..." -ForegroundColor Cyan
    $specialCharSessions = $jsonTitles | Where-Object { $_ -match '[^\x00-\x7F]' }
    if ($specialCharSessions.Count -gt 0) {
        Write-Host "Sessions with special characters:" -ForegroundColor Yellow
        $specialCharSessions | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
    } else {
        Write-Host "No special character issues found." -ForegroundColor Green
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
