# Find Missing Form Links
# Compare session titles to find which ones don't have form URLs

Write-Host "🔍 Finding sessions without form links..." -ForegroundColor Green

try {
    # Load sessions.json (new format)
    $sessionsData = Get-Content ".\sessions.json" | ConvertFrom-Json
    
    # Extract all sessions from the grouped structure
    $allSessions = @()
    foreach ($group in $sessionsData) {
        foreach ($session in $group.sessions) {
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
    
    # Load CSV form data
    $formsData = @{}
    if (Test-Path ".\output\session-forms.csv") {
        $csvLines = Get-Content ".\output\session-forms.csv"
        foreach ($line in $csvLines) {
            $fields = $line -split ','
            if ($fields.Count -ge 5) {
                $title = $fields[0].Trim('"')
                $formUrl = $fields[4].Trim('"')
                
                if ($formUrl -and $formUrl -ne "N/A" -and $formUrl -ne "ERROR" -and $formUrl.StartsWith("https://")) {
                    $formsData[$title] = $formUrl
                }
            }
        }
    }
    
    Write-Host "✓ Found $($validSessions.Count) valid sessions" -ForegroundColor Green
    Write-Host "✓ Found $($formsData.Count) form links" -ForegroundColor Green
    
    # Find missing sessions
    $missingSessions = @()
    foreach ($session in $validSessions) {
        if (-not $formsData.ContainsKey($session.title)) {
            $missingSessions += $session
        }
    }
    
    if ($missingSessions.Count -gt 0) {
        Write-Host "`n❌ Sessions WITHOUT form links ($($missingSessions.Count)):" -ForegroundColor Red
        foreach ($session in $missingSessions) {
            Write-Host "   - $($session.title)" -ForegroundColor Yellow
            Write-Host "     Speaker: $(($session.speakers | ForEach-Object { $_.name }) -join ', ')" -ForegroundColor Gray
            Write-Host "     Room: $($session.room)" -ForegroundColor Gray
        }
    } else {
        Write-Host "`n✅ All sessions have form links!" -ForegroundColor Green
    }
    
    # Check for close matches (title similarity)
    if ($missingSessions.Count -gt 0) {
        Write-Host "`n🔍 Checking for similar titles in CSV..." -ForegroundColor Cyan
        foreach ($missing in $missingSessions) {
            $csvTitles = $formsData.Keys
            $similarTitles = $csvTitles | Where-Object { 
                $_ -like "*$($missing.title.Substring(0, [Math]::Min(20, $missing.title.Length)))*" -or
                $missing.title -like "*$($_.Substring(0, [Math]::Min(20, $_.Length)))*"
            }
            
            if ($similarTitles.Count -gt 0) {
                Write-Host "   Missing: $($missing.title)" -ForegroundColor Yellow
                Write-Host "   Similar: $($similarTitles -join ', ')" -ForegroundColor Cyan
            }
        }
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
