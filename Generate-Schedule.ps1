<#
.SYNOPSIS
Generates a printable legal-sized landsca    $html = @"
<div class="day-section">
"@

    # Only add title if one is provided
    if ($dayTitle) {
        $html += "<h2 class='day-title'>$dayTitle</h2>`n"
    }
    
    $html += @"
    <table class="schedule-table">"@chedule document from Sessionize API data.

.DESCRIPTION
This script fetches session data from the Sessionize API and creates a formatted HTML document
that can be printed front and back on legal-sized paper in landscape orientation.

.PARAMETER ApiUrl
The Sessionize API URL for the event schedule data.

.PARAMETER OutputPath
Path where the HTML file will be saved.

.PARAMETER EventName
Name of the event for the document header.

.PARAMETER EventDate
Date of the event.

.EXAMPLE
.\Generate-Schedule.ps1 -OutputPath "schedule.html"

.NOTES
Designed for SQL Saturday Baton Rouge 2025 schedule formatting.
#>

[CmdletBinding()]
param(
    [string]$ApiUrl = "https://sessionize.com/api/v2/qta105as/view/GridSmart",
    [string]$OutputPath = "SQL_Saturday_Schedule.html",
    [string]$EventName = "SQL Saturday Baton Rouge 2025",
    [string]$EventDate = "July 25-26, 2025"
)

Write-Host "=== SQL Saturday Schedule Generator ===" -ForegroundColor Cyan
Write-Host "📡 Fetching data from Sessionize API..." -ForegroundColor Green

try {
    # Fetch data from API
    $response = Invoke-RestMethod -Uri $ApiUrl -Method Get
    Write-Host "✅ Successfully fetched schedule data" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to fetch data from API: $_"
    return
}

Write-Host "🔄 Processing schedule data..." -ForegroundColor Green

# Get only the main event day (Saturday)
$mainDay = $response | Where-Object { $_.date -eq "2025-07-26T00:00:00" }

# Function to create time slot grid for specific rooms
function New-TimeSlotGrid {
    param($dayData, $dayTitle, $roomsToInclude)
    
    $html = @"
<div class="day-section">
    <table class="schedule-table">
        <thead>
            <tr>
                <th class="time-column">Time</th>
"@

    # Use only the specified rooms
    foreach ($room in $roomsToInclude) {
        $roomName = $room.name -replace "BEC ", "" -replace " \(", "`n("
        $html += "<th class='room-column'>$roomName</th>`n"
    }
    
    $html += @"
            </tr>
        </thead>
        <tbody>
"@

    # Define the specific time slots for the schedule
    $timeSlots = @("08:30:00", "09:40:00", "10:45:00", "11:20:00", "12:20:00", "13:40:00", "14:45:00", "15:45:00")
    
    foreach ($timeSlot in $timeSlots) {
        $time = ([DateTime]::ParseExact($timeSlot, "HH:mm:ss", $null)).ToString("h:mm tt")
        
        # Special handling for keynote at 10:45
        if ($timeSlot -eq "10:45:00") {
            $html += "<tr class='keynote-row'>`n<td class='time-cell'>$time</td>`n"
            # Find keynote session in the data
            $keynoteSlot = $dayData.timeSlots | Where-Object { $_.slotStart -eq "10:45:00" } | Select-Object -First 1
            if ($keynoteSlot) {
                $keynoteSession = ($keynoteSlot.rooms | Where-Object { $_.session.isPlenumSession }).session
                if ($keynoteSession) {
                    $keynoteRoom = ($keynoteSlot.rooms | Where-Object { $_.session.isPlenumSession })
                    $roomName = if ($keynoteRoom) { $keynoteRoom.name -replace "BEC ", "" } else { "Auditorium" }
                    $colspan = $roomsToInclude.Count
                    $html += "<td class='keynote-cell' colspan='$colspan'>"
                    $html += "<div class='keynote-title'>🎤 $($keynoteSession.title)</div>`n"
                    $html += "<div class='keynote-speaker'>$($keynoteSession.speakers[0].name)</div>`n"
                    $html += "<div class='keynote-room'>📍 $roomName</div>`n"
                    $html += "</td>`n"
                }
            }
            $html += "</tr>`n"
            continue
        }
        
        # Special handling for lunch at 12:20
        if ($timeSlot -eq "12:20:00") {
            $html += "<tr class='lunch-row'>`n<td class='time-cell'>$time</td>`n"
            $colspan = $roomsToInclude.Count
            $html += "<td class='lunch-cell' colspan='$colspan'>"
            $html += "<div class='lunch-title'>LUNCH</div>`n"
            $html += "<div class='lunch-room'>📍 Atrium</div>`n"
            $html += "</td>`n"
            $html += "</tr>`n"
            continue
        }
        
        # Special handling for raffle at 3:45
        if ($timeSlot -eq "15:45:00") {
            $html += "<tr class='raffle-row'>`n<td class='time-cell'>$time</td>`n"
            $colspan = $roomsToInclude.Count
            $html += "<td class='raffle-cell' colspan='$colspan'>"
            $html += "<div class='raffle-title'>🎁 RAFFLE & CLOSING</div>`n"
            $html += "<div class='raffle-room'>📍 Auditorium</div>`n"
            $html += "</td>`n"
            $html += "</tr>`n"
            continue
        }
        
        # Regular session time slot - find all sessions that fall within this time window
        $html += "<tr>`n<td class='time-cell'>$time</td>`n"
        
        # Calculate time window for this slot (e.g., 8:30-9:40, 9:40-10:45, etc.)
        $currentTime = [DateTime]::ParseExact($timeSlot, "HH:mm:ss", $null)
        $nextTimeSlot = $timeSlots[([array]::IndexOf($timeSlots, $timeSlot) + 1)]
        $nextTime = if ($nextTimeSlot) { [DateTime]::ParseExact($nextTimeSlot, "HH:mm:ss", $null) } else { $currentTime.AddHours(2) }
        
        foreach ($room in $roomsToInclude) {
            $sessionsInRoom = @()
            
            # Find all sessions for this room that start within this time window
            foreach ($slot in $dayData.timeSlots) {
                $slotStart = [DateTime]::ParseExact($slot.slotStart, "HH:mm:ss", $null)
                
                # Check if this slot starts within our time window
                if ($slotStart -ge $currentTime -and $slotStart -lt $nextTime) {
                    $sessionInRoom = $slot.rooms | Where-Object { $_.id -eq $room.id }
                    
                    if ($sessionInRoom -and $sessionInRoom.session -and -not $sessionInRoom.session.isServiceSession) {
                        $session = $sessionInRoom.session
                        $startTime = ([DateTime]::ParseExact($slot.slotStart, "HH:mm:ss", $null)).ToString("h:mm tt")
                        $endTime = if ($slot.slotEnd) { ([DateTime]::ParseExact($slot.slotEnd, "HH:mm:ss", $null)).ToString("h:mm tt") } else { "" }
                        $duration = if ($slot.slotEnd) { 
                            ([DateTime]::ParseExact($slot.slotEnd, "HH:mm:ss", $null) - [DateTime]::ParseExact($slot.slotStart, "HH:mm:ss", $null)).TotalMinutes 
                        } else { 60 }
                        
                        $sessionsInRoom += @{
                            Session = $session
                            StartTime = $startTime
                            EndTime = $endTime
                            Duration = $duration
                        }
                    }
                }
            }
            
            if ($sessionsInRoom.Count -gt 0) {
                $html += "<td class='session-cell'>"
                
                foreach ($sessionInfo in $sessionsInRoom) {
                    $session = $sessionInfo.Session
                    $title = $session.title
                    $speakers = ($session.speakers | ForEach-Object { $_.name }) -join ", "
                    # Determine session level (exclude lightning talks and keynotes)
                    $level = ""
                    $isLightningTalk = $title -match "Lightning Talk" -or $sessionInfo.Duration -le 15
                    $isKeynote = $session.isPlenumSession
                    
                    if (-not $isLightningTalk -and -not $isKeynote) { 
                        if ($session.categoryItems -and $session.categoryItems.Count -gt 0) {
                            $levelCategory = $session.categoryItems | Where-Object { $_.name -match "Level|Beginner|Intermediate|Advanced|100|200|300|400" }
                            if ($levelCategory) { 
                                $level = "Level: " + $levelCategory.name 
                            } else {
                                # If no specific level found, default to "Intermediate" for regular sessions
                                $level = "Level: Intermediate"
                            }
                        } else {
                            # If no category items, default to "Intermediate" for regular sessions
                            $level = "Level: Intermediate"
                        }
                    }
                    
                    # Add session block if multiple sessions
                    if ($sessionsInRoom.Count -gt 1) {
                        $html += "<div class='session-block'>"
                    }
                    
                    $html += "<div class='session-title'>$title</div>`n"
                    if ($speakers) {
                        $html += "<div class='session-speaker'>$speakers</div>`n"
                    }
                    # Always show level for regular sessions (not lightning talks or keynotes)
                    if ($level) {
                        $html += "<div class='session-level'>$level</div>`n"
                    }
                    
                    # Show time info for shorter sessions or multiple sessions
                    if ($sessionInfo.Duration -lt 60 -or $sessionsInRoom.Count -gt 1) {
                        if ($sessionInfo.EndTime) {
                            $html += "<div class='session-time'>$($sessionInfo.StartTime) - $($sessionInfo.EndTime)</div>`n"
                        } else {
                            $html += "<div class='session-time'>$($sessionInfo.StartTime)</div>`n"
                        }
                    }
                    
                    if ($sessionsInRoom.Count -gt 1) {
                        $html += "</div>"
                    }
                }
                
                $html += "</td>`n"
            } else {
                $html += "<td class='empty-cell'></td>`n"
            }
        }
        $html += "</tr>`n"
    }
    
    $html += @"
        </tbody>
    </table>
    <div style="text-align: center; margin-top: 10px; font-size: 8px; color: #666; font-style: italic;">
        ➤ Continued on other side
    </div>
</div>
"@
    
    return $html
}

# Generate HTML content
$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$EventName - Schedule</title>
    <style>
        @page {
            size: letter landscape;
            margin: 0.5in;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            font-size: 10px;
            line-height: 1.2;
            margin: 0;
            padding: 0;
            color: #333;
        }
        
        .header {
            margin-bottom: 15px;
            border-bottom: 3px solid #2F5233;
            padding-bottom: 10px;
            position: relative;
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
        }
        
        .header-content {
            text-align: center;
            flex: 1;
        }
        
        .header-logo {
            height: 80px;
            width: auto;
            max-width: 120px;
            flex-shrink: 0;
        }
        
        .header h1 {
            margin: 0;
            font-size: 20px;
            color: #2F5233;
            font-weight: bold;
        }
        
        .header .date {
            font-size: 12px;
            color: #495057;
            margin: 3px 0;
        }
        
        .day-section {
            margin-bottom: 15px;
        }
        
        .schedule-table {
            width: 100%;
            border-collapse: collapse;
            border: 2px solid #2F5233;
            font-size: 9px;
        }
        
        .schedule-table th {
            background: #8FBC8F;
            color: white;
            padding: 8px 4px;
            text-align: center;
            font-weight: bold;
            font-size: 9px;
            border: 1px solid #2F5233;
            line-height: 1.1;
        }
        
        .time-column {
            width: 60px;
            min-width: 60px;
        }
        
        .room-column {
            width: auto;
            text-align: center;
            font-size: 8px;
            font-weight: bold;
            white-space: pre-line;
        }
        
        .schedule-table td {
            border: 1px solid #ccc;
            padding: 5px 3px;
            vertical-align: top;
            font-size: 9px;
            line-height: 1.1;
            height: 65px;
        }
        
        .schedule-table tr:nth-child(even) td {
            background-color: #f8f9fa;
        }
        
        .schedule-table tr:nth-child(odd) td {
            background-color: #ffffff;
        }
        
        .time-cell {
            font-weight: bold;
            text-align: center;
            color: #2F5233;
            white-space: nowrap;
            font-size: 10px;
            border-right: 2px solid #8FBC8F;
        }
        
        .session-cell {
            border-left: 2px solid #8FBC8F;
        }
        
        .session-title {
            font-weight: bold;
            color: #333;
            margin-bottom: 2px;
            line-height: 1.1;
            font-size: 9px;
        }
        
        .session-speaker {
            color: #666;
            font-style: italic;
            font-size: 8px;
        }
        
        .session-level {
            color: #2F5233;
            font-weight: bold;
            font-size: 7px;
            margin-top: 2px;
            text-transform: uppercase;
            background-color: #E8F5E8;
            padding: 1px 4px;
            border-radius: 2px;
            display: inline-block;
            border: 1px solid #8FBC8F;
        }
        
        .session-time {
            color: #2F5233;
            font-weight: bold;
            font-size: 7px;
            margin-top: 2px;
            background: #D4EDDA;
            padding: 1px 3px;
            border-radius: 2px;
            display: inline-block;
            border: 1px solid #8FBC8F;
        }
        
        .session-block {
            border-bottom: 1px solid #ddd;
            margin-bottom: 4px;
            padding-bottom: 4px;
        }
        
        .session-block:last-child {
            border-bottom: none;
            margin-bottom: 0;
            padding-bottom: 0;
        }
        
        .keynote-row {
            background: #f8f9fa;
        }
        
        .keynote-row td {
            background: #D4EDDA !important;
        }
        
        .keynote-cell {
            border: 2px solid #2F5233;
            text-align: center;
            padding: 8px;
        }
        
        .keynote-title {
            font-weight: bold;
            color: #2F5233;
            font-size: 10px;
            margin-bottom: 2px;
        }
        
        .keynote-speaker {
            color: #155724;
            font-style: italic;
            font-size: 8px;
        }
        
        .keynote-room {
            color: #2F5233;
            font-weight: bold;
            font-size: 8px;
            margin-top: 2px;
        }
        
        .lunch-row {
            background: #f8f9fa;
        }
        
        .lunch-row td {
            background: #E8F5E8 !important;
        }
        
        .lunch-cell {
            border: 2px solid #2F5233;
            text-align: center;
            padding: 8px;
        }
        
        .lunch-title {
            font-weight: bold;
            color: #2F5233;
            font-size: 10px;
            margin-bottom: 2px;
        }
        
        .lunch-room {
            color: #2F5233;
            font-weight: bold;
            font-size: 8px;
        }
        
        .raffle-row {
            background: #f8f9fa;
        }
        
        .raffle-row td {
            background: #CCE5CC !important;
        }
        
        .raffle-cell {
            border: 2px solid #2F5233;
            text-align: center;
            padding: 8px;
        }
        
        .raffle-title {
            font-weight: bold;
            color: #2F5233;
            font-size: 10px;
            margin-bottom: 2px;
        }
        
        .raffle-room {
            color: #2F5233;
            font-weight: bold;
            font-size: 8px;
        }
        
        .empty-cell {
            /* Inherits alternating background from tr:nth-child rules */
        }
        
        @media print {
            .day-section {
                page-break-after: always;
            }
            
            .day-section:last-child {
                page-break-after: auto;
            }
            
            .schedule-table td {
                height: 60px;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="header-content">
            <h1>$EventName</h1>
            <div class="date">Saturday, July 26, 2025</div>
            <div style="font-size: 10px; margin-top: 3px;">
                📍 LSU Business Education Complex • 🌐 www.sqlsatbr.com
            </div>
            <div style="font-size: 8px; margin-top: 3px; color: #495057;">
                🎫 FREE Event • 📝 Registration: 8:00 AM • 🎁 Raffle: 3:45 PM
            </div>
            <div style="font-size: 7px; margin-top: 5px; color: #666;">
                Schedule generated $(Get-Date -Format 'MMMM dd, yyyy') • For session abstracts and speaker bios, visit <strong>www.sqlsatbr.com</strong>
            </div>
        </div>
        <img src="Images/SQL_2025.png" alt="SQL Saturday Baton Rouge 2025 Logo" class="header-logo">
    </div>
"@

# Add main event day - split into two pages by rooms
if ($mainDay) {
    # Get all rooms (excluding Atrium which is just for registration/lunch)
    $allRooms = $mainDay.rooms | Where-Object { $_.name -ne "Atrium" } | Sort-Object name
    
    # Split rooms into two groups
    $totalRooms = $allRooms.Count
    $midPoint = [Math]::Ceiling($totalRooms / 2)
    
    $page1Rooms = $allRooms[0..($midPoint-1)]
    $page2Rooms = $allRooms[$midPoint..($totalRooms-1)]
    
    Write-Host "📅 Processing Page 1 Rooms: $($page1Rooms.name -join ', ')..." -ForegroundColor Yellow
    $page1Html = New-TimeSlotGrid -dayData $mainDay -dayTitle "" -roomsToInclude $page1Rooms
    $htmlContent += $page1Html
    
    Write-Host "📅 Processing Page 2 Rooms: $($page2Rooms.name -join ', ')..." -ForegroundColor Yellow
    $page2Html = New-TimeSlotGrid -dayData $mainDay -dayTitle "" -roomsToInclude $page2Rooms
    $htmlContent += $page2Html
}

# Add footer
$htmlContent += @"
</body>
</html>
"@

# Write the HTML file
try {
    $fullPath = Join-Path (Get-Location) $OutputPath
    $htmlContent | Out-File -FilePath $fullPath -Encoding UTF8
    Write-Host "✅ Schedule generated successfully!" -ForegroundColor Green
    Write-Host "📄 File saved to: $fullPath" -ForegroundColor Gray
    Write-Host "`n📋 Print Instructions:" -ForegroundColor Cyan
    Write-Host "   1. Open the HTML file in a web browser" -ForegroundColor White
    Write-Host "   2. Set printer to Letter size (8.5 x 11 inches)" -ForegroundColor White
    Write-Host "   3. Set orientation to Landscape" -ForegroundColor White
    Write-Host "   4. Enable double-sided printing (front and back)" -ForegroundColor White
    Write-Host "   5. Page 1: First half of rooms, Page 2: Second half of rooms" -ForegroundColor White
    Write-Host "   6. Adjust margins if needed (0.5 inch recommended)" -ForegroundColor White
    
    # Open the file if requested
    $openFile = Read-Host "`nWould you like to open the file now? (y/n)"
    if ($openFile -eq 'y' -or $openFile -eq 'Y') {
        Start-Process $fullPath
    }
    
} catch {
    Write-Error "❌ Failed to write HTML file: $_"
}

Write-Host "`n🎉 Schedule generation complete!" -ForegroundColor Green
