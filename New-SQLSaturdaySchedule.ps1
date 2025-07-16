<#
.SYNOPSIS
Generates a printable schedule document from Sessionize API data with customizable styling.

.DESCRIPTION
This script fetches session data from the Sessionize API and creates a formatted HTML document
that can be printed with customizable page size, colors, and layout options.

.PARAMETER ApiUrl
The Sessionize API URL for the event schedule data.

.PARAMETER OutputPath
Path where the HTML file will be saved.

.PARAMETER EventName
Name of the event for the document header.

.PARAMETER EventDate
Date string for the event (e.g., "July 26, 2025").

.PARAMETER EventDateFilter
ISO date string to filter which day to process (e.g., "2025-07-26T00:00:00").

.PARAMETER PageSize
Paper size for printing. Valid values: "letter", "legal", "a4".

.PARAMETER Orientation
Page orientation. Valid values: "landscape", "portrait".

.PARAMETER PrimaryColor
Primary color for headers and borders (hex format, e.g., "#2F5233").

.PARAMETER SecondaryColor
Secondary color for table headers and accents (hex format, e.g., "#8FBC8F").

.PARAMETER LogoPath
Relative path to the logo image file.

.PARAMETER LocationName
Name of the event location.

.PARAMETER Website
Website URL for the event.

.PARAMETER RoomPrefix
Prefix to remove from room names (e.g., "BEC ").

.EXAMPLE
.\New-SQLSaturdaySchedule.ps1 -ApiUrl "https://sessionize.com/api/v2/qta105as/view/GridSmart" -EventName "SQL Saturday City 2026" -EventDate "July 25, 2026" -EventDateFilter "2026-07-25T00:00:00" -PrimaryColor "#1B4B3A" -SecondaryColor "#7BAE7B"

.EXAMPLE
.\New-SQLSaturdaySchedule.ps1 -PageSize "legal" -PrimaryColor "#8B0000" -SecondaryColor "#CD5C5C" -LogoPath "Images/MyLogo.png"

.NOTES
Designed for SQL Saturday events but can be adapted for other conferences.
Time slots, keynotes, lunch, and raffle times are automatically detected from the schedule data.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ApiUrl,
    [string]$OutputPath,
    [Parameter(Mandatory=$true)]
    [string]$EventName,
    [Parameter(Mandatory=$true)]
    [string]$EventDate,
    [string]$EventDateFilter,
    [ValidateSet("letter", "legal", "a4")]
    [string]$PageSize = "letter",
    [ValidateSet("landscape", "portrait")]
    [string]$Orientation = "landscape",
    [string]$PrimaryColor = "#2F5233",
    [string]$SecondaryColor = "#8FBC8F",
    [string]$LogoPath,
    [string]$LocationName,
    [string]$Website,
    [string]$RoomPrefix
)

# Function to automatically detect time slots from schedule data
function Get-TimeSlots {
    param($dayData)
    
    # Get time slots based on sessions that have multiple concurrent rooms or are plenum sessions
    $mainTimeSlots = @()
    
    foreach ($slot in $dayData.timeSlots) {
        $regularSessions = $slot.rooms | Where-Object { 
            $_.session -and 
            -not $_.session.isServiceSession 
        }
        
        $plenumSessions = $slot.rooms | Where-Object { $_.session.isPlenumSession -eq $true }
        
        # Skip 8:00 AM slot only if it looks like registration/check-in
        if ($slot.slotStart -eq "08:00:00") {
            # Check if this 8:00 AM slot has actual sessions vs registration
            $hasRealSessions = $regularSessions | Where-Object { 
                $_.session.title -notmatch "registration|check.?in|sign.?in|welcome|opening" 
            }
            if (-not $hasRealSessions) {
                Write-Host "   ⏰ Skipping 8:00 AM slot - appears to be registration/check-in" -ForegroundColor Gray
                continue
            } else {
                Write-Host "   ⏰ Including 8:00 AM slot - contains regular sessions" -ForegroundColor Green
            }
        }
        
        # Include this time slot if:
        # 1. It has plenum sessions (keynote, lunch, raffle), OR
        # 2. It has multiple regular sessions (2+ concurrent sessions for smaller events), OR
        # 3. It has any regular sessions (for days with fewer concurrent sessions like Friday)
        if ($plenumSessions.Count -gt 0 -or $regularSessions.Count -ge 2 -or ($regularSessions.Count -ge 1 -and $dayData.rooms.Count -le 3)) {
            $mainTimeSlots += $slot.slotStart
        }
    }
    
    # Remove duplicates and sort
    $timeSlots = $mainTimeSlots | 
        Select-Object -Unique | 
        Sort-Object { [DateTime]::ParseExact($_, "HH:mm:ss", $null) }
    
    Write-Host "📅 Detected time slots: $($timeSlots -join ', ')" -ForegroundColor Yellow
    Write-Host "💡 Lightning talk sessions will be grouped within these main time blocks" -ForegroundColor Cyan
    return $timeSlots
}

# Function to detect special events (keynote, lunch, raffle) from plenum sessions
function Get-SpecialEvents {
    param($dayData)
    
    $specialEvents = @{
        KeynoteTime = $null
        LunchTime = $null
        RaffleTime = $null
    }
    
    foreach ($slot in $dayData.timeSlots) {
        $plenumSessions = $slot.rooms | Where-Object { $_.session.isPlenumSession -eq $true }
        
        foreach ($plenumSession in $plenumSessions) {
            if ($plenumSession.session) {
                $title = $plenumSession.session.title
                $time = $slot.slotStart
                
                # Detect lunch first (most specific)
                if ($title -match "lunch|break|meal" -and !$specialEvents.LunchTime) {
                    $specialEvents.LunchTime = $time
                    Write-Host "🍽️ Detected lunch at $time`: $title" -ForegroundColor Green
                }
                # Detect raffle/closing
                elseif ($title -match "raffle|closing|prize|giveaway" -and !$specialEvents.RaffleTime) {
                    $specialEvents.RaffleTime = $time
                    Write-Host "� Detected raffle/closing at $time`: $title" -ForegroundColor Green
                }
                # Detect keynote (exclude registration/check-in)
                elseif ($title -match "keynote" -and $title -notmatch "registration|check.?in|sign.?in" -and !$specialEvents.KeynoteTime) {
                    $specialEvents.KeynoteTime = $time
                    Write-Host "� Detected keynote at $time`: $title" -ForegroundColor Green
                }
                # Also look for opening sessions that aren't registration
                elseif ($title -match "opening|welcome" -and $title -notmatch "registration|check.?in|sign.?in" -and !$specialEvents.KeynoteTime) {
                    $specialEvents.KeynoteTime = $time
                    Write-Host "� Detected opening session at $time`: $title" -ForegroundColor Green
                }
            }
        }
    }
    
    return $specialEvents
}

# Function to create header HTML
function New-HeaderHtml {
    param(
        [string]$EventName,
        [string]$EventDate,
        [string]$LocationName,
        [string]$Website,
        [string]$LogoPath
    )
    
    $headerHtml = @"
    <div class="header">
        <div class="header-content">
            <h1>$EventName</h1>
            <div class="date">$EventDate</div>
"@

    # Add location and website if provided
    if ($LocationName -or $Website) {
        $headerHtml += "`n            <div style=`"font-size: 8px; margin-top: 2px;`">"
        if ($LocationName) {
            $headerHtml += "📍 $LocationName"
            if ($Website) { $headerHtml += " • " }
        }
        if ($Website) {
            $headerHtml += "🌐 $Website"
        }
        $headerHtml += "</div>"
    }

    $headerHtml += @"

            <div style="font-size: 7px; margin-top: 2px; color: #495057;">
                🎫 FREE Event • 📝 Registration: 8:00 AM • 🎁 Raffle: 3:45 PM
            </div>
            <div style="font-size: 6px; margin-top: 3px; color: #666;">
                Schedule generated $(Get-Date -Format 'MMMM dd, yyyy')
"@

    # Add website reference if provided
    if ($Website) {
        $headerHtml += " • For session abstracts and speaker bios, visit <strong>$Website</strong>"
    }

    $headerHtml += @"

            </div>
        </div>
"@

    # Add logo if provided
    if ($LogoPath) {
        $headerHtml += "`n        <img src=`"$LogoPath`" alt=`"$EventName Logo`" class=`"header-logo`">"
    }

    $headerHtml += @"

    </div>
"@

    return $headerHtml
}

# Function to create time slot grid for specific rooms
function New-TimeSlotGrid {
    param(
        $dayData, 
        $dayTitle, 
        $roomsToInclude,
        $timeSlots,
        $specialEvents,
        $roomPrefix,
        $EventName,
        $EventDate,
        $LocationName,
        $Website,
        $LogoPath,
        $IncludeHeader = $false
    )
    
    $html = @"
<div class="day-section">
"@

    # Add header only if requested (first page of each day)
    if ($IncludeHeader) {
        $headerHtml = New-HeaderHtml -EventName $EventName -EventDate $EventDate -LocationName $LocationName -Website $Website -LogoPath $LogoPath
        $html += $headerHtml
    }

    # Add day title if provided
    if ($dayTitle) {
        $html += @"
    <div class="day-title">$dayTitle</div>
"@
    }

    $html += @"
    <table class="schedule-table">
        <thead>
            <tr>
                <th class="time-column">Time</th>
"@

    # Use only the specified rooms
    foreach ($room in $roomsToInclude) {
        $roomName = $room.name -replace $roomPrefix, "" -replace " \(", "`n("
        $html += "<th class='room-column'>$roomName</th>`n"
    }
    
    $html += @"
            </tr>
        </thead>
        <tbody>
"@

    foreach ($timeSlot in $timeSlots) {
        $time = ([DateTime]::ParseExact($timeSlot, "HH:mm:ss", $null)).ToString("h:mm tt")
        
        # Check if this is a special event time
        $isSpecialEvent = $false
        $specialEventType = ""
        $specialEventTitle = ""
        $specialEventLocation = ""
        
        # Find plenum sessions for this time slot
        $currentSlot = $dayData.timeSlots | Where-Object { $_.slotStart -eq $timeSlot }
        if ($currentSlot) {
            $plenumSession = $currentSlot.rooms | Where-Object { $_.session.isPlenumSession -eq $true } | Select-Object -First 1
            if ($plenumSession -and $plenumSession.session) {
                $title = $plenumSession.session.title
                $location = $plenumSession.name -replace $roomPrefix, ""
                
                # Determine event type based on title
                if ($title -match "keynote|opening|welcome") {
                    $specialEventType = "keynote"
                    $specialEventTitle = "🎤 $title"
                    $isSpecialEvent = $true
                }
                elseif ($title -match "lunch|break|meal") {
                    $specialEventType = "lunch"
                    $specialEventTitle = "🍽️ LUNCH"
                    if ($title -match "jambalaya") { $specialEventTitle = "🍲 JAMBALAYA LUNCH" }
                    $isSpecialEvent = $true
                }
                elseif ($title -match "raffle|closing|prize|giveaway") {
                    $specialEventType = "raffle"
                    $specialEventTitle = "🎁 RAFFLE & CLOSING"
                    $isSpecialEvent = $true
                }
                
                $specialEventLocation = $location
                
                # Add speaker info for keynotes
                if ($specialEventType -eq "keynote" -and $plenumSession.session.speakers -and $plenumSession.session.speakers.Count -gt 0) {
                    $specialEventTitle += "`n" + $plenumSession.session.speakers[0].name
                }
            }
        }
        
        # Handle special events
        if ($isSpecialEvent) {
            $html += "<tr class='$specialEventType-row'>`n<td class='time-cell'>$time</td>`n"
            $colspan = $roomsToInclude.Count
            $html += "<td class='$specialEventType-cell' colspan='$colspan'>"
            $html += "<div class='$specialEventType-title'>$specialEventTitle</div>`n"
            if ($specialEventLocation) {
                $html += "<div class='$specialEventType-room'>📍 $specialEventLocation</div>`n"
            }
            $html += "</td>`n"
            $html += "</tr>`n"
            continue
        }
        
        # Regular session time slot - find all sessions that fall within this time window
        $html += "<tr>`n<td class='time-cell'>$time</td>`n"
        
        # Calculate time window for this slot (e.g., 8:30-9:40, 9:40-10:45, etc.)
        $currentTime = [DateTime]::ParseExact($timeSlot, "HH:mm:ss", $null)
        $nextTimeSlotIndex = ([array]::IndexOf($timeSlots, $timeSlot) + 1)
        $nextTimeSlot = if ($nextTimeSlotIndex -lt $timeSlots.Count) { $timeSlots[$nextTimeSlotIndex] } else { $null }
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

# Function to generate CSS with configurable colors and page size
function New-ScheduleCSS {
    param(
        [string]$PageSize,
        [string]$Orientation,
        [string]$PrimaryColor,
        [string]$SecondaryColor
    )
    
    # Calculate lighter versions of colors for backgrounds
    $lightPrimaryColor = $PrimaryColor + "20"  # Add transparency
    $lightSecondaryColor = $SecondaryColor + "20"
    
    return @"
        @page {
            size: $PageSize $Orientation;
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
            margin-bottom: 10px;
            border-bottom: 2px solid $PrimaryColor;
            padding-bottom: 6px;
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
            height: 60px;
            width: auto;
            max-width: 100px;
            flex-shrink: 0;
        }
        
        .header h1 {
            margin: 0;
            font-size: 16px;
            color: $PrimaryColor;
            font-weight: bold;
            line-height: 1.1;
        }
        
        .header .date {
            font-size: 10px;
            color: #495057;
            margin: 2px 0;
        }
        
        .day-section {
            margin-bottom: 15px;
        }
        
        .day-title {
            font-size: 14px;
            font-weight: bold;
            color: $PrimaryColor;
            text-align: center;
            margin-bottom: 10px;
            padding: 5px;
            border-bottom: 2px solid $SecondaryColor;
        }
        
        .schedule-table {
            width: 100%;
            border-collapse: collapse;
            border: 2px solid $PrimaryColor;
            font-size: 9px;
        }
        
        .schedule-table th {
            background: $SecondaryColor;
            color: white;
            padding: 8px 4px;
            text-align: center;
            font-weight: bold;
            font-size: 9px;
            border: 1px solid $PrimaryColor;
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
            color: $PrimaryColor;
            white-space: nowrap;
            font-size: 10px;
            border-right: 2px solid $SecondaryColor;
        }
        
        .session-cell {
            border-left: 2px solid $SecondaryColor;
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
            color: $PrimaryColor;
            font-weight: bold;
            font-size: 7px;
            margin-top: 2px;
            text-transform: uppercase;
            background-color: ${lightPrimaryColor};
            padding: 1px 4px;
            border-radius: 2px;
            display: inline-block;
            border: 1px solid $SecondaryColor;
        }
        
        .session-time {
            color: $PrimaryColor;
            font-weight: bold;
            font-size: 7px;
            margin-top: 2px;
            background: ${lightSecondaryColor};
            padding: 1px 3px;
            border-radius: 2px;
            display: inline-block;
            border: 1px solid $SecondaryColor;
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
        
        .keynote-row, .lunch-row, .raffle-row {
            background: #f8f9fa;
        }
        
        .keynote-row td {
            background: ${lightSecondaryColor} !important;
        }
        
        .lunch-row td {
            background: ${lightPrimaryColor} !important;
        }
        
        .raffle-row td {
            background: ${lightSecondaryColor} !important;
        }
        
        .keynote-cell, .lunch-cell, .raffle-cell {
            border: 2px solid $PrimaryColor;
            text-align: center;
            padding: 8px;
        }
        
        .keynote-title, .lunch-title, .raffle-title {
            font-weight: bold;
            color: $PrimaryColor;
            font-size: 10px;
            margin-bottom: 2px;
        }
        
        .keynote-speaker {
            color: $PrimaryColor;
            font-style: italic;
            font-size: 8px;
        }
        
        .keynote-room, .lunch-room, .raffle-room {
            color: $PrimaryColor;
            font-weight: bold;
            font-size: 8px;
            margin-top: 2px;
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
"@
}

# Main execution
Write-Host "=== SQL Saturday Schedule Generator ===" -ForegroundColor Cyan
Write-Host "📡 Fetching data from Sessionize API..." -ForegroundColor Green

# Set default values for optional parameters
if (-not $OutputPath) { $OutputPath = "Schedule.html" }
if (-not $RoomPrefix) { $RoomPrefix = "" }

try {
    # Fetch data from API
    $response = Invoke-RestMethod -Uri $ApiUrl -Method Get
    Write-Host "✅ Successfully fetched schedule data" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to fetch data from API: $_"
    return
}

Write-Host "🔄 Processing schedule data..." -ForegroundColor Green

# Determine which days to process
$daysToProcess = @()
if ($EventDateFilter) {
    # Use provided filter for specific day
    $specificDay = $response | Where-Object { $_.date -eq $EventDateFilter }
    if ($specificDay) {
        $daysToProcess += $specificDay
        Write-Host "✅ Processing specific date: $($specificDay.date)" -ForegroundColor Green
    } else {
        Write-Error "❌ No schedule data found for date: $EventDateFilter"
        return
    }
} else {
    # Process all available days
    $daysToProcess = $response | Sort-Object { [DateTime]$_.date }
    Write-Host "📅 Processing all available days: $($daysToProcess.date -join ', ')" -ForegroundColor Green
}

if ($daysToProcess.Count -eq 0) {
    Write-Error "❌ No schedule data found in API response"
    return
}

# Automatically detect time slots and special events for each day
Write-Host "🔍 Analyzing schedule structure..." -ForegroundColor Cyan

# Process each day individually
$allDayPages = @()
foreach ($currentDay in $daysToProcess) {
    $dayName = ([DateTime]$currentDay.date).ToString("dddd, MMMM dd, yyyy")
    
    Write-Host "📅 Processing $dayName..." -ForegroundColor Yellow
    
    $timeSlots = Get-TimeSlots -dayData $currentDay
    $specialEvents = Get-SpecialEvents -dayData $currentDay
    
    # Get all rooms for this day (excluding service rooms like Atrium)
    $allRooms = $currentDay.rooms | Where-Object { 
        $_.name -ne "Atrium" -and 
        $_.name -notmatch "Registration|Check.?in|Lobby" 
    } | Sort-Object name
    
    if ($allRooms.Count -eq 0) {
        Write-Host "⚠️ No session rooms found for $dayName, skipping..." -ForegroundColor Yellow
        continue
    }
    
    Write-Host "🏢 Found $($allRooms.Count) rooms: $($allRooms.name -join ', ')" -ForegroundColor Cyan
    
    # Determine how to split rooms for this day
    if ($allRooms.Count -le 5) {
        # Small number of rooms - put all on one page, add blank page for printing
        Write-Host "📄 Single page layout for $dayName (adding blank page for printing)" -ForegroundColor Green
        $page1Rooms = $allRooms
        $page2Rooms = @()  # Empty for blank page
        
        $page1Html = New-TimeSlotGrid -dayData $currentDay -dayTitle $dayName -roomsToInclude $page1Rooms -timeSlots $timeSlots -specialEvents $specialEvents -roomPrefix $RoomPrefix -EventName $EventName -EventDate $EventDate -LocationName $LocationName -Website $Website -LogoPath $LogoPath -IncludeHeader $true
        $allDayPages += $page1Html
        
        # Add blank page (no header)
        $blankPageHtml = @"
<div class="day-section">
    <div style="text-align: center; padding-top: 200px; font-size: 16px; color: #666;">
        <div style="margin-bottom: 20px;">📄 This page intentionally left blank</div>
        <div style="font-size: 12px;">For double-sided printing alignment</div>
    </div>
</div>
"@
        $allDayPages += $blankPageHtml
        
    } else {
        # Split rooms across two pages
        Write-Host "📄 Two-page layout for $dayName" -ForegroundColor Green
        $midPoint = [Math]::Ceiling($allRooms.Count / 2)
        $page1Rooms = $allRooms[0..($midPoint-1)]
        $page2Rooms = $allRooms[$midPoint..($allRooms.Count-1)]
        
        Write-Host "   📋 Page 1: $($page1Rooms.name -join ', ')" -ForegroundColor White
        Write-Host "   📋 Page 2: $($page2Rooms.name -join ', ')" -ForegroundColor White
        
        $page1Html = New-TimeSlotGrid -dayData $currentDay -dayTitle "$dayName (Page 1 of 2)" -roomsToInclude $page1Rooms -timeSlots $timeSlots -specialEvents $specialEvents -roomPrefix $RoomPrefix -EventName $EventName -EventDate $EventDate -LocationName $LocationName -Website $Website -LogoPath $LogoPath -IncludeHeader $true
        $page2Html = New-TimeSlotGrid -dayData $currentDay -dayTitle "$dayName (Page 2 of 2)" -roomsToInclude $page2Rooms -timeSlots $timeSlots -specialEvents $specialEvents -roomPrefix $RoomPrefix -EventName $EventName -EventDate $EventDate -LocationName $LocationName -Website $Website -LogoPath $LogoPath -IncludeHeader $false
        
        $allDayPages += $page1Html
        $allDayPages += $page2Html
    }
}

Write-Host "✅ Schedule analysis complete! Generated $($allDayPages.Count) pages total." -ForegroundColor Green

# Generate CSS with custom colors and page size
$css = New-ScheduleCSS -PageSize $PageSize -Orientation $Orientation -PrimaryColor $PrimaryColor -SecondaryColor $SecondaryColor

# Generate HTML content
$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$EventName - Schedule</title>
    <style>
$css
    </style>
</head>
<body>
"@

# Add all processed day pages
foreach ($pageHtml in $allDayPages) {
    $htmlContent += $pageHtml
}

# Add footer
$htmlContent += @"
</body>
</html>
"@

# Write the HTML file
try {
    # Handle output path properly - support both relative and absolute paths
    if ([System.IO.Path]::IsPathRooted($OutputPath)) {
        # OutputPath is already an absolute path
        $fullPath = $OutputPath
    } else {
        # OutputPath is relative or just a filename - combine with current directory
        $fullPath = Join-Path (Get-Location) $OutputPath
    }
    
    # Ensure the directory exists
    $directory = [System.IO.Path]::GetDirectoryName($fullPath)
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    
    $htmlContent | Out-File -FilePath $fullPath -Encoding UTF8
    Write-Host "✅ Schedule generated successfully!" -ForegroundColor Green
    Write-Host "📄 File saved to: $fullPath" -ForegroundColor Gray
    Write-Host "`n📋 Print Instructions:" -ForegroundColor Cyan
    Write-Host "   1. Open the HTML file in a web browser" -ForegroundColor White
    Write-Host "   2. Set printer to $PageSize size" -ForegroundColor White
    Write-Host "   3. Set orientation to $Orientation" -ForegroundColor White
    Write-Host "   4. Enable double-sided printing (front and back)" -ForegroundColor White
    Write-Host "   5. Each day is formatted for optimal printing (max 2 pages per day)" -ForegroundColor White
    Write-Host "   6. Blank pages are included for proper double-sided alignment" -ForegroundColor White
    Write-Host "   7. Adjust margins if needed (0.5 inch recommended)" -ForegroundColor White
    
    # Show customization info
    Write-Host "`n🎨 Customization Applied:" -ForegroundColor Magenta
    Write-Host "   • Page Size: $PageSize $Orientation" -ForegroundColor White
    Write-Host "   • Primary Color: $PrimaryColor" -ForegroundColor White
    Write-Host "   • Secondary Color: $SecondaryColor" -ForegroundColor White
    Write-Host "   • Logo: $LogoPath" -ForegroundColor White
    
    # Open the file if requested
    $openFile = Read-Host "`nWould you like to open the file now? (y/n)"
    if ($openFile -eq 'y' -or $openFile -eq 'Y') {
        Start-Process $fullPath
    }
    
} catch {
    Write-Error "❌ Failed to write HTML file: $_"
}

Write-Host "`n🎉 Schedule generation complete!" -ForegroundColor Green