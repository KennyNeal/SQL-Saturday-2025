# Generate Website with Session Feedback Form Links
# Creates HTML pages that can be uploaded to Google Sites or any web hosting

param(
    [Parameter(Mandatory = $false)]
    [string]$SessionDataPath = ".\sessions.json",
    
    [Parameter(Mandatory = $false)]
    [string]$FormsDataPath = ".\output\session-forms.csv",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\output\website"
)

Write-Host "🌐 Generating Session Feedback Website..." -ForegroundColor Green

try {
    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-Host "✓ Created output directory: $OutputPath" -ForegroundColor Green
    }
    
    # Load session data
    if (-not (Test-Path $SessionDataPath)) {
        throw "Session data file not found: $SessionDataPath"
    }
    
    $sessionsData = Get-Content $SessionDataPath | ConvertFrom-Json
    Write-Host "✓ Loaded session data" -ForegroundColor Green
    
    # Load form links (if available)
    $formsData = @{}
    if (Test-Path $FormsDataPath) {
        $formsCsv = Import-Csv $FormsDataPath
        foreach ($form in $formsCsv) {
            if ($form.FormUrl -and $form.FormUrl -ne "N/A") {
                $formsData[$form.SessionTitle] = $form.FormUrl
            }
        }
        Write-Host "✓ Loaded $($formsData.Count) form links" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Forms data not found. Will generate template with placeholder links." -ForegroundColor Yellow
    }
    
    # Group sessions by room with precons prioritized
    $sessionsByRoom = @{}
    $preconSessions = @()
    
    foreach ($session in $sessionsData.sessions) {
        # Check if this is a precon first (usually longer sessions, often in LA Tech Park rooms)
        $isPrecon = $session.room -match "LA Tech Park" -or 
                   $session.title -match "Precon|Pre-Con|Half.?Day|Full.?Day" -or
                   ($session.categories | Where-Object { $_.categoryItems | Where-Object { $_.name -match "Preconference" } })
        
        # Skip service sessions and non-feedback sessions, but NOT precons
        if ($session.isServiceSession -or 
            ($session.title -match "Lunch|Break|Registration|Keynote|Welcome|Closing" -and -not $isPrecon) -or
            $session.roomId -eq 20946 -or $session.roomId -eq 20947) {
            continue
        }
        
        if ($isPrecon) {
            $preconSessions += $session
        } else {
            $roomName = $session.room
            if (-not $sessionsByRoom.ContainsKey($roomName)) {
                $sessionsByRoom[$roomName] = @()
            }
            $sessionsByRoom[$roomName] += $session
        }
    }
    
    # Calculate stats
    $totalRooms = $sessionsByRoom.Keys.Count + ($preconSessions.Count -gt 0 ? 1 : 0)
    $totalSessions = ($sessionsByRoom.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum + $preconSessions.Count
    
    # Build HTML content more carefully - more compact design
    $htmlContent = @()
    $htmlContent += '<!DOCTYPE html>'
    $htmlContent += '<html lang="en">'
    $htmlContent += '<head>'
    $htmlContent += '    <meta charset="UTF-8">'
    $htmlContent += '    <meta name="viewport" content="width=device-width, initial-scale=1.0">'
    $htmlContent += '    <title>SQL Saturday Baton Rouge 2025 - Session Feedback</title>'
    $htmlContent += '    <style>'
    $htmlContent += '        body { font-family: Arial, sans-serif; max-width: 1400px; margin: 0 auto; padding: 15px; background: #f8f9fa; font-size: 14px; }'
    $htmlContent += '        .header { text-align: center; background: #667eea; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }'
    $htmlContent += '        .header h1 { margin: 0; font-size: 1.8em; }'
    $htmlContent += '        .header p { margin: 8px 0; font-size: 1em; opacity: 0.9; }'
    $htmlContent += '        .stats { display: flex; justify-content: center; gap: 25px; margin: 15px 0; }'
    $htmlContent += '        .stat { text-align: center; }'
    $htmlContent += '        .stat-number { font-size: 1.4em; font-weight: bold; }'
    $htmlContent += '        .stat-label { font-size: 0.8em; opacity: 0.8; }'
    $htmlContent += '        .room-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 15px; }'
    $htmlContent += '        .room-card { background: white; border-radius: 6px; padding: 15px; box-shadow: 0 2px 6px rgba(0,0,0,0.1); }'
    $htmlContent += '        .precon-card { border: 2px solid #dc2626; background: linear-gradient(135deg, #fff5f5 0%, #fef2f2 100%); }'
    $htmlContent += '        .regular-card { border: 1px solid #e5e7eb; }'
    $htmlContent += '        .precon-card { border-left: 4px solid #dc3545; }'
    $htmlContent += '        .regular-card { border-left: 4px solid #28a745; }'
    $htmlContent += '        .room-card h2 { margin: 0 0 12px 0; color: #333; font-size: 1.1em; border-bottom: 1px solid #eee; padding-bottom: 6px; }'
    $htmlContent += '        .precon-header { color: #dc2626; border-bottom: 2px solid #dc2626; padding-bottom: 8px; margin-bottom: 15px; }'
    $htmlContent += '        .precon-header { color: #dc3545; font-weight: bold; }'
    $htmlContent += '        .session-item { margin-bottom: 8px; padding: 8px; background: #f8f9fa; border-radius: 4px; }'
    $htmlContent += '        .session-title { font-weight: bold; color: #333; margin-bottom: 2px; font-size: 0.95em; line-height: 1.2; }'
    $htmlContent += '        .session-speaker { color: #666; font-size: 0.8em; margin-bottom: 6px; }'
    $htmlContent += '        .feedback-link { display: inline-block; background: #28a745; color: white; padding: 4px 8px; text-decoration: none; border-radius: 3px; font-size: 0.8em; }'
    $htmlContent += '        .feedback-link:hover { background: #218838; }'
    $htmlContent += '        .placeholder-link { background: #6c757d; cursor: not-allowed; }'
    $htmlContent += '        .precon-link { background: #dc3545; }'
    $htmlContent += '        .precon-link:hover { background: #c82333; }'
    $htmlContent += '        .footer { text-align: center; margin-top: 20px; padding: 15px; background: white; border-radius: 6px; font-size: 0.9em; }'
    $htmlContent += '    </style>'
    $htmlContent += '</head>'
    $htmlContent += '<body>'
    $htmlContent += '    <div class="header">'
    $htmlContent += '        <h1>SQL Saturday Baton Rouge 2025</h1>'
    $htmlContent += '        <p>Session Feedback Forms</p>'
    $htmlContent += '        <div class="stats">'
    $htmlContent += "            <div class='stat'><div class='stat-number'>$totalRooms</div><div class='stat-label'>Rooms</div></div>"
    $htmlContent += "            <div class='stat'><div class='stat-number'>$totalSessions</div><div class='stat-label'>Sessions</div></div>"
    $htmlContent += '        </div>'
    $htmlContent += '    </div>'
    $htmlContent += '    <div class="room-grid">'

    # Add precons first (at the top)
    if ($preconSessions.Count -gt 0) {
        $sortedPrecons = $preconSessions | Sort-Object startsAt
        
        $htmlContent += '        <div class="room-card precon-card">'
        $htmlContent += '            <h2 class="precon-header">🎯 Pre-Conference Sessions</h2>'
        
        foreach ($session in $sortedPrecons) {
            $speakerNames = ($session.speakers | ForEach-Object { $_.name }) -join ", "
            $sessionTime = ""
            if ($session.startsAt) {
                $startTime = [DateTime]::Parse($session.startsAt).ToString("h:mm tt")
                $sessionTime = " - $startTime"
            }
            
            # Clean up session title for HTML
            $cleanTitle = $session.title -replace '"', '&quot;' -replace '<', '&lt;' -replace '>', '&gt;'
            $cleanSpeakers = $speakerNames -replace '"', '&quot;' -replace '<', '&lt;' -replace '>', '&gt;'
            
            $formUrl = $formsData[$session.title]
            $linkClass = if ($formUrl) { "feedback-link precon-link" } else { "feedback-link placeholder-link" }
            $linkText = if ($formUrl) { "Feedback" } else { "Coming Soon" }
            $linkHref = if ($formUrl) { $formUrl } else { "#" }
            
            $htmlContent += '            <div class="session-item">'
            $htmlContent += "                <div class='session-title'>$cleanTitle</div>"
            $htmlContent += "                <div class='session-speaker'>by $cleanSpeakers$sessionTime</div>"
            $htmlContent += "                <a href='$linkHref' class='$linkClass' target='_blank'>$linkText</a>"
            $htmlContent += '            </div>'
        }
        
        $htmlContent += '        </div>'
    }
    
    # Add regular room sections
    foreach ($roomName in ($sessionsByRoom.Keys | Sort-Object)) {
        $sessions = $sessionsByRoom[$roomName] | Sort-Object startsAt
        
        $htmlContent += '        <div class="room-card regular-card">'
        $htmlContent += "            <h2>$roomName</h2>"
        
        foreach ($session in $sessions) {
            $speakerNames = ($session.speakers | ForEach-Object { $_.name }) -join ", "
            $sessionTime = ""
            if ($session.startsAt) {
                $startTime = [DateTime]::Parse($session.startsAt).ToString("h:mm tt")
                $sessionTime = " - $startTime"
            }
            
            # Clean up session title for HTML
            $cleanTitle = $session.title -replace '"', '&quot;' -replace '<', '&lt;' -replace '>', '&gt;'
            $cleanSpeakers = $speakerNames -replace '"', '&quot;' -replace '<', '&lt;' -replace '>', '&gt;'
            
            $formUrl = $formsData[$session.title]
            $linkClass = if ($formUrl) { "feedback-link" } else { "feedback-link placeholder-link" }
            $linkText = if ($formUrl) { "Feedback" } else { "Coming Soon" }
            $linkHref = if ($formUrl) { $formUrl } else { "#" }
            
            $htmlContent += '            <div class="session-item">'
            $htmlContent += "                <div class='session-title'>$cleanTitle</div>"
            $htmlContent += "                <div class='session-speaker'>by $cleanSpeakers$sessionTime</div>"
            $htmlContent += "                <a href='$linkHref' class='$linkClass' target='_blank'>$linkText</a>"
            $htmlContent += '            </div>'
        }
        
        $htmlContent += '        </div>'
    }
    
    # Close the HTML
    $htmlContent += '    </div>'
    $htmlContent += '    <div class="footer">'
    $htmlContent += '        <h3>About Session Feedback</h3>'
    $htmlContent += '        <p>Your feedback helps speakers improve and helps us plan better events.</p>'
    $htmlContent += '        <p><strong>Each form includes:</strong> Speaker knowledge, Presentation skills, Demos, Learning expectations (1-5 ratings) plus improvement suggestions and positive feedback (text).</p>'
    $htmlContent += "        <p><small>Generated on $(Get-Date -Format "MMMM dd, yyyy 'at' h:mm tt")</small></p>"
    $htmlContent += '    </div>'
    $htmlContent += '</body>'
    $htmlContent += '</html>'

    # Save main page
    $indexPath = Join-Path $OutputPath "index.html"
    $htmlContent -join "`n" | Set-Content $indexPath -Encoding UTF8
    Write-Host "✓ Generated main page: $indexPath" -ForegroundColor Green
    
    # Generate individual room pages
    foreach ($roomName in ($sessionsByRoom.Keys | Sort-Object)) {
        $sessions = $sessionsByRoom[$roomName] | Sort-Object startsAt
        $safeRoomName = $roomName -replace '[^\w\s-]', '' -replace '\s+', '-'
        
        $roomHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$roomName - SQL Saturday Baton Rouge 2025 Feedback</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .header {
            text-align: center;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px 20px;
            border-radius: 10px;
            margin-bottom: 30px;
        }
        .back-link {
            display: inline-block;
            margin-bottom: 20px;
            color: #667eea;
            text-decoration: none;
            font-weight: bold;
        }
        .back-link:hover {
            text-decoration: underline;
        }
        .session-card {
            background: white;
            border-radius: 10px;
            padding: 25px;
            margin-bottom: 20px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            border-left: 5px solid #28a745;
        }
        .session-title {
            font-size: 1.4em;
            font-weight: bold;
            color: #333;
            margin-bottom: 10px;
        }
        .session-speaker {
            color: #666;
            margin-bottom: 15px;
            font-size: 1.1em;
        }
        .feedback-link {
            display: inline-block;
            background: #28a745;
            color: white;
            padding: 12px 24px;
            text-decoration: none;
            border-radius: 5px;
            font-weight: bold;
            transition: background 0.3s ease;
        }
        .feedback-link:hover {
            background: #218838;
            text-decoration: none;
            color: white;
        }
        .placeholder-link {
            background: #6c757d;
            cursor: not-allowed;
        }
    </style>
</head>
<body>
    <a href="index.html" class="back-link">← Back to All Rooms</a>
    
    <div class="header">
        <h1>$roomName</h1>
        <p>Session Feedback Forms</p>
    </div>

"@

        foreach ($session in $sessions) {
            $speakerNames = ($session.speakers | ForEach-Object { $_.name }) -join ", "
            $sessionTime = ""
            if ($session.startsAt) {
                $startTime = [DateTime]::Parse($session.startsAt).ToString("h:mm tt")
                $sessionTime = " - $startTime"
            }
            
            $formUrl = $formsData[$session.title]
            $linkClass = if ($formUrl) { "feedback-link" } else { "feedback-link placeholder-link" }
            $linkText = if ($formUrl) { "📝 Give Feedback for This Session" } else { "📝 Feedback Form Coming Soon" }
            $linkHref = if ($formUrl) { $formUrl } else { "#" }
            
            $roomHtml += @"
    <div class="session-card">
        <div class="session-title">$($session.title)</div>
        <div class="session-speaker">by $speakerNames$sessionTime</div>
        <a href="$linkHref" class="$linkClass" target="_blank" rel="noopener">$linkText</a>
    </div>

"@
        }
        
        $roomHtml += @"
</body>
</html>
"@

        $roomPath = Join-Path $OutputPath "$safeRoomName.html"
        $roomHtml | Set-Content $roomPath -Encoding UTF8
        Write-Host "✓ Generated room page: $roomPath" -ForegroundColor Green
    }
    
    # Generate upload instructions
    $instructionsHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Upload Instructions - SQL Saturday Feedback Site</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            line-height: 1.6;
        }
        .header {
            background: #667eea;
            color: white;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
            margin-bottom: 30px;
        }
        .step {
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
        }
        .step h3 {
            margin-top: 0;
            color: #495057;
        }
        code {
            background: #e9ecef;
            padding: 2px 6px;
            border-radius: 4px;
            font-family: 'Courier New', monospace;
        }
        .note {
            background: #d1ecf1;
            border: 1px solid #bee5eb;
            border-radius: 6px;
            padding: 15px;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Google Sites Upload Instructions</h1>
        <p>How to upload your session feedback website</p>
    </div>

    <div class="step">
        <h3>Step 1: Access Your Google Site</h3>
        <p>Go to <strong>sites.google.com</strong> and open your existing Google Sites website.</p>
    </div>

    <div class="step">
        <h3>Step 2: Create a New Page</h3>
        <p>Click the <strong>+ (Plus)</strong> button to create a new page, or edit an existing page where you want to add the feedback forms.</p>
    </div>

    <div class="step">
        <h3>Step 3: Embed HTML Content</h3>
        <p>In your Google Site editor:</p>
        <ol>
            <li>Click <strong>Insert → Embed → Embed code</strong></li>
            <li>Copy the contents of <code>index.html</code> from this folder</li>
            <li>Paste it into the embed code box</li>
            <li>Click <strong>Insert</strong></li>
        </ol>
    </div>

    <div class="note">
        <strong>Alternative Method:</strong> You can also copy sections of the HTML and paste them directly into Google Sites text blocks. The styling might be simplified, but the links will work.
    </div>

    <div class="step">
        <h3>Step 4: Update Form Links</h3>
        <p>After you generate the actual Google Forms:</p>
        <ol>
            <li>Run the main form generation script</li>
            <li>Re-run this website generator (it will pick up the real form URLs)</li>
            <li>Update your Google Site with the new HTML</li>
        </ol>
    </div>

    <div class="step">
        <h3>Step 5: Publish</h3>
        <p>Click <strong>Publish</strong> in the top-right corner of your Google Site to make the changes live.</p>
    </div>

    <div class="note">
        <strong>Files Generated:</strong><br>
        • <code>index.html</code> - Main page with all rooms<br>
        • <code>[Room-Name].html</code> - Individual room pages<br>
        • <code>upload-instructions.html</code> - This instruction page
    </div>

</body>
</html>
"@

    $instructionsPath = Join-Path $OutputPath "upload-instructions.html"
    $instructionsHtml | Set-Content $instructionsPath -Encoding UTF8
    Write-Host "✓ Generated upload instructions: $instructionsPath" -ForegroundColor Green
    
    Write-Host "`n🎉 Website generation completed!" -ForegroundColor Green
    Write-Host "Generated files in: $OutputPath" -ForegroundColor Cyan
    Write-Host "• Main page: index.html" -ForegroundColor White
    Write-Host "• Individual room pages: $($sessionsByRoom.Keys.Count) files" -ForegroundColor White
    Write-Host "• Upload instructions: upload-instructions.html" -ForegroundColor White
    
    if ($formsData.Count -eq 0) {
        Write-Host "`n💡 Note: Form links are placeholders until you generate the actual forms." -ForegroundColor Yellow
        Write-Host "After running Generate-SessionFeedbackForms.ps1, run this script again to get real links." -ForegroundColor Yellow
    }
    
    # Open the main page for preview
    $indexFullPath = Resolve-Path $indexPath
    Write-Host "`n🌐 Opening preview..." -ForegroundColor Green
    Start-Process $indexFullPath
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
