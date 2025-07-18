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
Relative or absolute path to the logo image file. If relative, it will be resolved relative to the project root first, then current directory.

.PARAMETER LocationName
Name of the event location.

.PARAMETER Website
Website URL for the event.

.PARAMETER RoomPrefix
Prefix to remove from room names (e.g., "BEC ").

.PARAMETER AppUrl
URL for the mobile app (e.g., "https://sqlsatbr25.sessionize.com/"). If provided, a QR code will be added to the header.

.PARAMETER GeneratePDF
If specified, generates a PDF version of the schedule in addition to the HTML file using Microsoft Edge headless mode.

.EXAMPLE
.\New-SQLSaturdaySchedule.ps1 -ApiUrl "https://sessionize.com/api/v2/qta105as/view/GridSmart" -EventName "SQL Saturday City 2026" -EventDate "July 25, 2026" -EventDateFilter "2026-07-25T00:00:00" -PrimaryColor "#1B4B3A" -SecondaryColor "#7BAE7B"

.EXAMPLE
.\New-SQLSaturdaySchedule.ps1 -PageSize "legal" -PrimaryColor "#8B0000" -SecondaryColor "#CD5C5C" -LogoPath "assets/images/MyLogo.png"

.EXAMPLE
.\New-SQLSaturdaySchedule.ps1 -LogoPath "C:\MyProject\logo.png" -EventName "Custom Event" -EventDate "Jan 1, 2026"

.EXAMPLE
.\New-SQLSaturdaySchedule.ps1 -ApiUrl "https://sessionize.com/api/v2/qta105as/view/GridSmart" -EventName "SQL Saturday City 2026" -EventDate "July 25, 2026" -GeneratePDF

.NOTES
Designed for SQL Saturday events but can be adapted for other conferences.
Time slots, keynotes, lunch, and raffle times are automatically detected from the schedule data.
Requires Microsoft Edge browser for PDF generation.
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
    [string]$RoomPrefix,
    [string]$AppUrl,
    [switch]$GeneratePDF
)

# Function to generate a simple QR code using an online service
function New-QRCodeSVG {
    param(
        [string]$Url,
        [int]$Size = 80
    )
    
    # Use qr-server.com API to generate QR code as SVG
    $qrApiUrl = "https://api.qrserver.com/v1/create-qr-code/?size=${Size}x${Size}&format=svg&data=" + [System.Web.HttpUtility]::UrlEncode($Url)
    
    return $qrApiUrl
}

# Function to calculate optimal room distribution across pages based on content width
function Get-OptimalRoomDistribution {
    param(
        $rooms,
        [string]$pageSize,
        [string]$roomPrefix
    )
    
    # Calculate approximate available width for content based on page size (landscape)
    $pageWidths = @{
        "letter" = 10.4    # 11" - 0.6" total margins = 10.4" available width
        "legal" = 13.2     # 14" - 0.8" total margins = 13.2" available width  
        "a4" = 11.1        # 11.7" - 0.6" total margins ≈ 11.1" available width
    }
    
    $availableWidth = $pageWidths[$pageSize.ToLower()] ?? $pageWidths["letter"]
    
    # Reserve space for time column (approximately 0.8 inches)
    $timeColumnWidth = 0.7
    $contentWidth = $availableWidth - $timeColumnWidth
    
    Write-Host "📐 Page analysis: $pageSize size = $availableWidth inches total, $contentWidth inches for room columns" -ForegroundColor Cyan
    
    # Calculate estimated width for each room name (characters * average character width + padding)
    $avgCharWidth = 0.07  # Approximate inches per character in 8pt font
    $columnPadding = 0.3  # Padding and borders per column
    
    # First pass: calculate all room widths and total width needed (optimized)
    $roomWidths = [System.Collections.Generic.List[hashtable]]::new($rooms.Count)
    $totalWidth = 0
    
    # Pre-compile regex patterns for better performance
    $prefixRegex = if ($roomPrefix) { [regex]::new([regex]::Escape($roomPrefix)) } else { $null }
    $parenthesesRegex = [regex]::new(' \(')
    
    foreach ($room in $rooms) {
        # Calculate display name (after removing prefix and formatting) - optimized regex usage
        $displayName = $room.name
        if ($prefixRegex) { $displayName = $prefixRegex.Replace($displayName, "", 1) }
        $displayName = $parenthesesRegex.Replace($displayName, "`n(", 1)
        
        # Estimate column width needed for this room
        # Take the longest line after line breaks for width calculation
        $lines = $displayName -split "`n"
        $maxLineLength = ($lines | Measure-Object -Property Length -Maximum).Maximum
        $estimatedWidth = ($maxLineLength * $avgCharWidth) + $columnPadding
        
        # Ensure minimum width for readability
        $columnWidth = [Math]::Max($estimatedWidth, 1.2)
        
        $roomWidths.Add(@{
            CharLength = $maxLineLength
            Width = $columnWidth
            Room = $room
            DisplayName = $displayName
        })
        $totalWidth += $columnWidth
        
        Write-Host "   📏 Room '$($room.name)' → '$displayName' = $maxLineLength chars ≈ $($columnWidth.ToString('F1')) inches" -ForegroundColor Gray
    }
    
    # First check if all rooms actually fit on one page
    Write-Host "🔢 Total width needed: $($totalWidth.ToString('F1')) inches, available width: $($contentWidth.ToString('F1')) inches" -ForegroundColor Yellow
    
    # Try to distribute rooms evenly across the minimum number of pages
    $roomPages = @()
    
    if ($totalWidth -le $contentWidth) {
        # All rooms fit on one page - create a single page containing all rooms
        $singlePage = [PSCustomObject]@{
            Rooms = $rooms
            PageNumber = 1
        }
        $roomPages = @($singlePage)
        Write-Host "✅ All $($rooms.Count) rooms fit on single page" -ForegroundColor Green
    } else {
        # Calculate minimum number of pages needed based on total width
        $minPagesNeeded = [Math]::Ceiling($totalWidth / $contentWidth)
        Write-Host "📄 Splitting into $minPagesNeeded pages" -ForegroundColor Yellow
        
        # Distribute rooms as evenly as possible across pages
        $targetRoomsPerPage = [Math]::Ceiling($rooms.Count / $minPagesNeeded)
        Write-Host "🎯 Target: $targetRoomsPerPage rooms per page across $minPagesNeeded pages" -ForegroundColor Cyan
        
        # Create balanced distribution (optimized)
        $roomPages = [System.Collections.Generic.List[PSCustomObject]]::new($minPagesNeeded)
        for ($pageNum = 0; $pageNum -lt $minPagesNeeded; $pageNum++) {
            $startIndex = $pageNum * $targetRoomsPerPage
            $endIndex = [Math]::Min($startIndex + $targetRoomsPerPage - 1, $rooms.Count - 1)
            
            if ($startIndex -lt $rooms.Count) {
                $pageRooms = $rooms[$startIndex..$endIndex]
                $pageWidth = ($roomWidths[$startIndex..$endIndex] | Measure-Object -Property Width -Sum).Sum
                
                $pageObject = [PSCustomObject]@{
                    Rooms = $pageRooms
                    PageNumber = $pageNum + 1
                }
                $roomPages.Add($pageObject)
                Write-Host "   📄 Page $($pageNum + 1): $($pageRooms.Count) rooms, $($pageWidth.ToString('F1')) inches width" -ForegroundColor Green
                Write-Host "      📋 Rooms: $($pageRooms.name -join ', ')" -ForegroundColor White
            }
        }
        
        # If the last page exceeds width, try to rebalance by moving one room from previous page
        if ($roomPages.Count -ge 2) {
            $lastPageIndex = $roomPages.Count - 1
            $lastPageRooms = $roomPages[$lastPageIndex]
            $lastPageWidth = 0
            foreach ($room in $lastPageRooms) {
                $roomWidth = ($roomWidths | Where-Object { $_.Room.id -eq $room.id }).Width
                $lastPageWidth += $roomWidth
            }
            
            if ($lastPageWidth -gt $contentWidth -and $roomPages[$lastPageIndex - 1].Count -gt 1) {
                Write-Host "⚖️ Rebalancing: Last page too wide ($($lastPageWidth.ToString('F1')) inches), moving room from previous page" -ForegroundColor Yellow
                
                # Move last room from previous page to current page
                $prevPageRooms = [System.Collections.ArrayList]::new($roomPages[$lastPageIndex - 1])
                $roomToMove = $prevPageRooms[-1]
                $prevPageRooms.RemoveAt($prevPageRooms.Count - 1)
                
                $newLastPageRooms = @($roomToMove) + $lastPageRooms
                
                $roomPages[$lastPageIndex - 1] = $prevPageRooms.ToArray()
                $roomPages[$lastPageIndex] = $newLastPageRooms
                
                Write-Host "   🔄 Moved '$($roomToMove.name)' to last page for better balance" -ForegroundColor Magenta
            }
        }
    }
    
    # Final summary
    Write-Host "🎯 Final distribution: $($roomPages.Count) pages" -ForegroundColor Green
    for ($i = 0; $i -lt $roomPages.Count; $i++) {
        $pageRooms = $roomPages[$i].Rooms
        $pageWidth = 0
        foreach ($room in $pageRooms) {
            $roomWidth = ($roomWidths | Where-Object { $_.Room.id -eq $room.id }).Width
            $pageWidth += $roomWidth
        }
        Write-Host "   📄 Page $($i + 1): $($pageRooms.Count) rooms, $($pageWidth.ToString('F1')) inches" -ForegroundColor Yellow
    }
    
    return $roomPages
}
function Get-TimeSlots {
    param($dayData)
    
    # Get time slots based on sessions that have multiple concurrent rooms or are plenum sessions
    $mainTimeSlots = [System.Collections.Generic.List[string]]::new()
    
    foreach ($slot in $dayData.timeSlots) {
        $regularSessions = $slot.rooms | Where-Object { 
            $_.session -and 
            -not $_.session.isServiceSession 
        }
        
        $plenumSessions = $slot.rooms | Where-Object { $_.session.isPlenumSession -eq $true }
        
        # Skip slots that contain only registration/check-in plenum sessions
        $hasRegistrationPlenum = $plenumSessions | Where-Object { 
            $_.session.title -match "registration|check.?in|sign.?in|welcome|opening" 
        }
        
        if ($hasRegistrationPlenum -and $regularSessions.Count -eq 0) {
            Write-Host "   ⏰ Skipping slot at $($slot.slotStart) - appears to be registration/check-in" -ForegroundColor Gray
            continue
        } elseif ($hasRegistrationPlenum -and $regularSessions.Count -gt 0) {
            Write-Host "   ⏰ Including slot at $($slot.slotStart) - contains regular sessions alongside registration" -ForegroundColor Green
        }
        
        # Include this time slot if:
        # 1. It has plenum sessions (keynote, lunch, raffle), OR
        # 2. It has multiple regular sessions (2+ concurrent sessions for smaller events), OR
        # 3. It has any regular sessions (for days with fewer concurrent sessions like Friday)
        if ($plenumSessions.Count -gt 0 -or $regularSessions.Count -ge 2 -or ($regularSessions.Count -ge 1 -and $dayData.rooms.Count -le 3)) {
            $mainTimeSlots.Add($slot.slotStart)
        }
    }
    
    # Remove duplicates and sort - convert to array and optimize sorting
    $uniqueSlots = [System.Collections.Generic.HashSet[string]]::new($mainTimeSlots)
    $timeSlots = [array]($uniqueSlots | Sort-Object { [DateTime]::ParseExact($_, "HH:mm:ss", $null) })
    
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
        RegistrationTime = $null
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
                    Write-Host "🎁 Detected raffle/closing at $time`: $title" -ForegroundColor Green
                }
                # Detect registration/check-in
                elseif ($title -match "registration|check.?in|sign.?in" -and !$specialEvents.RegistrationTime) {
                    $specialEvents.RegistrationTime = $time
                    Write-Host "📝 Detected registration at $time`: $title" -ForegroundColor Green
                }
                # Detect keynote (exclude registration/check-in)
                elseif ($title -match "keynote" -and $title -notmatch "registration|check.?in|sign.?in" -and !$specialEvents.KeynoteTime) {
                    $specialEvents.KeynoteTime = $time
                    Write-Host "🎤 Detected keynote at $time`: $title" -ForegroundColor Green
                }
                # Also look for opening sessions that aren't registration
                elseif ($title -match "opening|welcome" -and $title -notmatch "registration|check.?in|sign.?in" -and !$specialEvents.KeynoteTime) {
                    $specialEvents.KeynoteTime = $time
                    Write-Host "🎤 Detected opening session at $time`: $title" -ForegroundColor Green
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
        [string]$LogoPath,
        [string]$AppUrl,
        [hashtable]$SpecialEvents
    )
    
    $headerHtml = @"
    <div class="header">
"@

    # Add QR code if AppUrl is provided
    if ($AppUrl) {
        $qrCodeUrl = New-QRCodeSVG -Url $AppUrl -Size 60
        $headerHtml += @"
        <div class="header-qr">
            <img src="$qrCodeUrl" alt="App QR Code" class="qr-code">
            <div class="qr-text">Use the App</div>
        </div>
"@
    }

    $headerHtml += @"
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
"@

    # Build dynamic time information based on special events
    $timeInfo = @()
    
    # Add registration time if available
    if ($SpecialEvents -and $SpecialEvents.RegistrationTime) {
        $registrationTime = ([DateTime]::ParseExact($SpecialEvents.RegistrationTime, "HH:mm:ss", $null)).ToString("h:mm tt")
        $timeInfo += "📝 Registration: $registrationTime"
    } elseif ($SpecialEvents -and $SpecialEvents.KeynoteTime) {
        # If no explicit registration time, use keynote time as proxy (assuming registration is before keynote)
        $keynoteDateTime = [DateTime]::ParseExact($SpecialEvents.KeynoteTime, "HH:mm:ss", $null)
        $registrationDateTime = $keynoteDateTime.AddMinutes(-30)  # Assume registration 30 minutes before keynote
        $registrationTime = $registrationDateTime.ToString("h:mm tt")
        $timeInfo += "📝 Registration: $registrationTime"
    }
    # No fallback - leave blank if not found
    
    # Add raffle time if available
    if ($SpecialEvents -and $SpecialEvents.RaffleTime) {
        $raffleTime = ([DateTime]::ParseExact($SpecialEvents.RaffleTime, "HH:mm:ss", $null)).ToString("h:mm tt")
        $timeInfo += "🎁 Raffle: $raffleTime"
    }
    # No fallback - leave blank if not found
    
    # Only add the time info div if we have any time information
    if ($timeInfo.Count -gt 0) {
        $headerHtml += "                " + ($timeInfo -join " • ") + @"

            </div>
"@
    } else {
        # Close the div tag if no time info
        $headerHtml += @"
            </div>
"@
    }
    
    $headerHtml += @"
            <div style="font-size: 6px; margin-top: 3px; color: #666;">
                Schedule generated $(Get-Date -Format 'MMMM dd, yyyy') and is subject to change • For session abstracts and speaker bios, visit www.sqlsatbr.com
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
        $AppUrl,
        $IncludeHeader = $false
    )
    
    # Use StringBuilder for efficient string building
    $htmlBuilder = [System.Text.StringBuilder]::new(8192)
    [void]$htmlBuilder.AppendLine('<div class="day-section">')
    
    # Add header only if requested (first page of each day)
    if ($IncludeHeader) {
        $headerHtml = New-HeaderHtml -EventName $EventName -EventDate $EventDate -LocationName $LocationName -Website $Website -LogoPath $LogoPath -AppUrl $AppUrl -SpecialEvents $specialEvents
        [void]$htmlBuilder.Append($headerHtml)
    }

    # Add day title if provided
    if ($dayTitle) {
        [void]$htmlBuilder.AppendLine("    <div class='day-title'>$dayTitle</div>")
    }

    [void]$htmlBuilder.AppendLine(@"
    <table class="schedule-table">
        <thead>
            <tr>
                <th class="time-column">Time</th>
"@)

    # Use only the specified rooms - optimize regex operations
    $prefixRegex = if ($roomPrefix) { [regex]::new([regex]::Escape($roomPrefix)) } else { $null }
    $parenthesesRegex = [regex]::new(' \(')
    
    foreach ($room in $roomsToInclude) {
        $roomName = $room.name
        if ($prefixRegex) { $roomName = $prefixRegex.Replace($roomName, "", 1) }
        $roomName = $parenthesesRegex.Replace($roomName, "`n(", 1)
        [void]$htmlBuilder.AppendLine("<th class='room-column'>$roomName</th>")
    }
    
    [void]$htmlBuilder.AppendLine(@"
            </tr>
        </thead>
        <tbody>
"@)

    # Pre-compile common regex patterns for session processing
    $jambalayaRegex = [regex]::new("jambalaya", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $timeSlotDateTimes = @{}
    
    # Pre-parse all time slots for better performance
    foreach ($slot in $timeSlots) {
        $timeSlotDateTimes[$slot] = [DateTime]::ParseExact($slot, "HH:mm:ss", $null)
    }

    foreach ($timeSlot in $timeSlots) {
        $time = $timeSlotDateTimes[$timeSlot].ToString("h:mm tt")
        
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
                $location = if ($prefixRegex) { $prefixRegex.Replace($plenumSession.name, "", 1) } else { $plenumSession.name }
                
                # Determine event type based on title - use optimized matching
                if ($title -match "keynote|opening|welcome") {
                    $specialEventType = "keynote"
                    $specialEventTitle = "🎤 $title"
                    $isSpecialEvent = $true
                }
                elseif ($title -match "lunch|break|meal") {
                    $specialEventType = "lunch"
                    $specialEventTitle = if ($jambalayaRegex.IsMatch($title)) { "🍲 JAMBALAYA LUNCH" } else { "🍽️ LUNCH" }
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
            # Check if there are also regular sessions during this special event time
            $regularSessionsInSlot = @()
            if ($currentSlot) {
                $regularSessionsInSlot = $currentSlot.rooms | Where-Object { 
                    $_.session -and 
                    -not $_.session.isServiceSession -and 
                    -not $_.session.isPlenumSession 
                }
            }
            
            # If there are regular sessions during a special event (e.g., lunch session), show both
            if ($regularSessionsInSlot.Count -gt 0) {
                Write-Host "   ⏰ Special event at $timeSlot has $($regularSessionsInSlot.Count) concurrent regular sessions" -ForegroundColor Magenta
                
                # Show the special event in a smaller format
                [void]$htmlBuilder.AppendLine("<tr class='mixed-event-row'>")
                [void]$htmlBuilder.AppendLine("<td class='time-cell'>$time</td>")
                
                # Calculate how many columns should show lunch vs regular sessions
                $lunchColumnCount = 0
                $regularSessionRooms = @()
                
                foreach ($room in $roomsToInclude) {
                    $sessionInRoom = $regularSessionsInSlot | Where-Object { $_.id -eq $room.id }
                    if ($sessionInRoom -and $sessionInRoom.session) {
                        $regularSessionRooms += $room
                    } else {
                        $lunchColumnCount++
                    }
                }
                
                # Show lunch columns first (combined if multiple)
                if ($lunchColumnCount -gt 0) {
                    [void]$htmlBuilder.AppendLine("<td class='$specialEventType-cell special-event-small' colspan='$lunchColumnCount'>")
                    [void]$htmlBuilder.AppendLine("<div class='$specialEventType-title-small'>$specialEventTitle</div>")
                    if ($specialEventLocation) {
                        [void]$htmlBuilder.AppendLine("<div class='$specialEventType-room-small'>📍 $specialEventLocation</div>")
                    }
                    [void]$htmlBuilder.AppendLine("</td>")
                }
                
                # Show regular sessions in remaining columns
                foreach ($room in $regularSessionRooms) {
                    $sessionInRoom = $regularSessionsInSlot | Where-Object { $_.id -eq $room.id }
                    
                    if ($sessionInRoom -and $sessionInRoom.session) {
                        $session = $sessionInRoom.session
                        $title = $session.title
                        $speakers = ($session.speakers | ForEach-Object { $_.name }) -join ", "
                        
                        # Determine session level and track (same as regular sessions)
                        $level = ""
                        $track = ""
                        $isLightningTalk = $title -match "Lightning Talk"
                        $isKeynote = $session.isPlenumSession
                        
                        if (-not $isLightningTalk -and -not $isKeynote) { 
                            # Parse categories array for level and track information
                            if ($session.categories -and $session.categories.Count -gt 0) {
                                # Find Level category
                                $levelCategory = $session.categories | Where-Object { $_.name -eq "Level" }
                                if ($levelCategory -and $levelCategory.categoryItems -and $levelCategory.categoryItems.Count -gt 0) {
                                    $levelValue = $levelCategory.categoryItems[0].name
                                    $level = "Level: " + $levelValue
                                }
                                
                                # Find Track category
                                $trackCategory = $session.categories | Where-Object { $_.name -eq "Track" }
                                if ($trackCategory -and $trackCategory.categoryItems -and $trackCategory.categoryItems.Count -gt 0) {
                                    $trackValue = $trackCategory.categoryItems[0].name
                                    # Only show track if different from room name and not generic
                                    if ($trackValue -ne $room.name -and $trackValue -notmatch "Room|Track") {
                                        $track = $trackValue
                                    }
                                }
                            }
                        }
                        
                        [void]$htmlBuilder.AppendLine("<td class='session-cell'>")
                        [void]$htmlBuilder.AppendLine("<div class='session-title'>$title</div>")
                        if ($speakers) {
                            [void]$htmlBuilder.AppendLine("<div class='session-speaker'>$speakers</div>")
                        }
                        
                        # Show level for regular sessions
                        if ($level) {
                            [void]$htmlBuilder.AppendLine("<div class='session-level'>$level</div>")
                        }
                        
                        # Show track information if available
                        if ($track) {
                            [void]$htmlBuilder.AppendLine("<div class='session-track'>Track: $track</div>")
                        }
                        
                        [void]$htmlBuilder.AppendLine("</td>")
                    }
                }
                
                [void]$htmlBuilder.AppendLine("</tr>")
            } else {
                # No regular sessions, show special event across all columns as before
                [void]$htmlBuilder.AppendLine("<tr class='$specialEventType-row'>")
                [void]$htmlBuilder.AppendLine("<td class='time-cell'>$time</td>")
                $colspan = $roomsToInclude.Count
                [void]$htmlBuilder.AppendLine("<td class='$specialEventType-cell' colspan='$colspan'>")
                [void]$htmlBuilder.AppendLine("<div class='$specialEventType-title'>$specialEventTitle</div>")
                if ($specialEventLocation) {
                    [void]$htmlBuilder.AppendLine("<div class='$specialEventType-room'>📍 $specialEventLocation</div>")
                }
                [void]$htmlBuilder.AppendLine("</td>")
                [void]$htmlBuilder.AppendLine("</tr>")
            }
            continue
        }
        
        # Regular session time slot - find all sessions that fall within this time window
        [void]$htmlBuilder.AppendLine("<tr>")
        [void]$htmlBuilder.AppendLine("<td class='time-cell'>$time</td>")
        
        # Calculate time window for this slot (e.g., 8:30-9:40, 9:40-10:45, etc.)
        $currentTime = $timeSlotDateTimes[$timeSlot]
        $nextTimeSlotIndex = ([array]::IndexOf($timeSlots, $timeSlot) + 1)
        $nextTime = if ($nextTimeSlotIndex -lt $timeSlots.Count) { 
            $timeSlotDateTimes[$timeSlots[$nextTimeSlotIndex]]
        } else { 
            $currentTime.AddHours(2) 
        }
        
        foreach ($room in $roomsToInclude) {
            $sessionsInRoom = [System.Collections.Generic.List[hashtable]]::new()
            
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
                        
                        $sessionsInRoom.Add(@{
                            Session = $session
                            StartTime = $startTime
                            EndTime = $endTime
                            Duration = $duration
                        })
                    }
                }
            }
            
            if ($sessionsInRoom.Count -gt 0) {
                [void]$htmlBuilder.AppendLine("<td class='session-cell'>")
                
                foreach ($sessionInfo in $sessionsInRoom) {
                    $session = $sessionInfo.Session
                    $title = $session.title
                    $speakers = ($session.speakers | ForEach-Object { $_.name }) -join ", "
                    # Determine session level (exclude lightning talks and keynotes)
                    $level = ""
                    $track = ""
                    $isLightningTalk = $title -match "Lightning Talk" -or $sessionInfo.Duration -le 15
                    $isKeynote = $session.isPlenumSession
                    
                    if (-not $isLightningTalk -and -not $isKeynote) { 
                        # Parse categories array for level and track information
                        if ($session.categories -and $session.categories.Count -gt 0) {
                            # Find Level category (id: 93749)
                            $levelCategory = $session.categories | Where-Object { $_.name -eq "Level" }
                            if ($levelCategory -and $levelCategory.categoryItems -and $levelCategory.categoryItems.Count -gt 0) {
                                $levelValue = $levelCategory.categoryItems[0].name
                                $level = "Level: " + $levelValue
                            }
                            
                            # Find Track category (id: 93748) 
                            $trackCategory = $session.categories | Where-Object { $_.name -eq "Track" }
                            if ($trackCategory -and $trackCategory.categoryItems -and $trackCategory.categoryItems.Count -gt 0) {
                                $trackValue = $trackCategory.categoryItems[0].name
                                # Only show track if different from room name and not generic
                                if ($trackValue -ne $room.name -and $trackValue -notmatch "Room|Track") {
                                    $track = $trackValue
                                }
                            }
                        }
                    }
                    
                    # Add session block if multiple sessions
                    if ($sessionsInRoom.Count -gt 1) {
                        [void]$htmlBuilder.AppendLine("<div class='session-block'>")
                    }
                    
                    [void]$htmlBuilder.AppendLine("<div class='session-title'>$title</div>")
                    if ($speakers) {
                        [void]$htmlBuilder.AppendLine("<div class='session-speaker'>$speakers</div>")
                    }
                    
                    # Show level for regular sessions (not lightning talks or keynotes)
                    if ($level) {
                        [void]$htmlBuilder.AppendLine("<div class='session-level'>$level</div>")
                    }
                    
                    # Show track information if available and different from room name
                    if ($track) {
                        [void]$htmlBuilder.AppendLine("<div class='session-track'>Track: $track</div>")
                    }
                    
                    # Show time info for shorter sessions or multiple sessions
                    if ($sessionInfo.Duration -lt 60 -or $sessionsInRoom.Count -gt 1) {
                        if ($sessionInfo.EndTime) {
                            [void]$htmlBuilder.AppendLine("<div class='session-time'>$($sessionInfo.StartTime) - $($sessionInfo.EndTime)</div>")
                        } else {
                            [void]$htmlBuilder.AppendLine("<div class='session-time'>$($sessionInfo.StartTime)</div>")
                        }
                    }
                    
                    if ($sessionsInRoom.Count -gt 1) {
                        [void]$htmlBuilder.AppendLine("</div>")
                    }
                }
                
                [void]$htmlBuilder.AppendLine("</td>")
            } else {
                [void]$htmlBuilder.AppendLine("<td class='empty-cell'></td>")
            }
        }
        [void]$htmlBuilder.AppendLine("</tr>")
    }
    
    [void]$htmlBuilder.AppendLine(@"
        </tbody>
    </table>
    <div style="text-align: center; margin-top: 10px; font-size: 8px; color: #666; font-style: italic;">
        ➤ Continued on other side
    </div>
</div>
"@)
    
    return $htmlBuilder.ToString()
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
    
    # Set margins based on page size for optimal fit
    $pageMargin = switch ($PageSize) {
        "letter" { "0.3in" }    # Tighter margins for letter size PDF
        "legal" { "0.4in" }     # Tighter margins for legal
        "a4" { "0.3in" }        # Tighter margins for A4
        default { "0.4in" }
    }
    
    return @"
        @page {
            size: $PageSize $Orientation;
            margin: $pageMargin;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            font-size: 10px;
            line-height: 1.2;
            margin: 0;
            padding: 0;
            color: #333;
            box-sizing: border-box;
        }
        
        .header {
            margin-bottom: 8px;
            border-bottom: 2px solid $PrimaryColor;
            padding-bottom: 4px;
            position: relative;
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
        }
        
        .header-qr {
            display: flex;
            flex-direction: column;
            align-items: center;
            margin-right: 10px;
            flex-shrink: 0;
        }
        
        .qr-code {
            width: 60px;
            height: 60px;
            border: 1px solid $SecondaryColor;
        }
        
        .qr-text {
            font-size: 7px;
            color: $PrimaryColor;
            font-weight: bold;
            margin-top: 2px;
            text-align: center;
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
            table-layout: fixed;
        }
        
        .schedule-table th {
            background: $SecondaryColor;
            color: white;
            padding: 6px 3px;
            text-align: center;
            font-weight: bold;
            font-size: 8px;
            border: 1px solid $PrimaryColor;
            line-height: 1.1;
        }
        
        .time-column {
            width: 55px;
            min-width: 55px;
        }
        
        .room-column {
            width: auto;
            text-align: center;
            font-size: 7px;
            font-weight: bold;
            white-space: pre-line;
        }
        
        .schedule-table td {
            border: 1px solid #ccc;
            padding: 3px 2px;
            vertical-align: top;
            font-size: 8px;
            line-height: 1.1;
            height: 65px;
            overflow: hidden;
            word-wrap: break-word;
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
            font-size: 9px;
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
            font-size: 8px;
        }
        
        .session-speaker {
            color: #666;
            font-style: italic;
            font-size: 7px;
        }
        
        .session-level {
            color: $PrimaryColor;
            font-weight: bold;
            font-size: 6px;
            margin-top: 2px;
            text-transform: uppercase;
            background-color: ${lightPrimaryColor};
            padding: 1px 3px;
            border-radius: 2px;
            display: inline-block;
            border: 1px solid $SecondaryColor;
        }
        
        .session-track {
            color: $SecondaryColor;
            font-weight: bold;
            font-size: 6px;
            margin-top: 2px;
            text-transform: uppercase;
            background-color: ${lightSecondaryColor};
            padding: 1px 3px;
            border-radius: 2px;
            display: inline-block;
            border: 1px solid $PrimaryColor;
            margin-left: 3px;
        }
        
        .session-time {
            color: $PrimaryColor;
            font-weight: bold;
            font-size: 6px;
            margin-top: 2px;
            background: ${lightSecondaryColor};
            padding: 1px 2px;
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
        
        .mixed-event-row {
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
        
        /* Only apply special event background to special event cells in mixed rows */
        .mixed-event-row .lunch-cell,
        .mixed-event-row .keynote-cell,
        .mixed-event-row .raffle-cell {
            background: ${lightPrimaryColor} !important;
        }
        
        /* Regular session cells in mixed rows keep default styling */
        .mixed-event-row .session-cell {
            background: #ffffff;
        }
        
        .keynote-cell, .lunch-cell, .raffle-cell {
            border: 2px solid $PrimaryColor;
            text-align: center;
            padding: 4px;
            height: 40px;
        }
        
        .special-event-small {
            border: 2px solid $PrimaryColor;
            text-align: center;
            padding: 2px;
            height: 80px;
            font-size: 8px;
        }
        
        .keynote-title, .lunch-title, .raffle-title {
            font-weight: bold;
            color: $PrimaryColor;
            font-size: 9px;
            margin-bottom: 1px;
            line-height: 1.0;
        }
        
        .keynote-title-small, .lunch-title-small, .raffle-title-small {
            font-weight: bold;
            color: $PrimaryColor;
            font-size: 7px;
            margin-bottom: 1px;
            line-height: 1.0;
        }
        
        .keynote-speaker {
            color: $PrimaryColor;
            font-style: italic;
            font-size: 7px;
            line-height: 1.0;
        }
        
        .keynote-room, .lunch-room, .raffle-room {
            color: $PrimaryColor;
            font-weight: bold;
            font-size: 7px;
            margin-top: 1px;
            line-height: 1.0;
        }
        
        .keynote-room-small, .lunch-room-small, .raffle-room-small {
            color: $PrimaryColor;
            font-weight: bold;
            font-size: 6px;
            margin-top: 1px;
            line-height: 1.0;
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
                height: 65px;
            }
            
            .keynote-cell, .lunch-cell, .raffle-cell {
                height: 45px;
            }
            
            .special-event-small {
                height: 65px;
            }
        }
"@
}

# Main execution
Write-Host "=== SQL Saturday Schedule Generator ===" -ForegroundColor Cyan

# Input validation
if (-not $ApiUrl -or $ApiUrl -notmatch '^https?://') {
    Write-Error "❌ ApiUrl must be a valid HTTP/HTTPS URL"
    return
}

if ($PrimaryColor -notmatch '^#[0-9A-Fa-f]{6}$') {
    Write-Error "❌ PrimaryColor must be a valid hex color (e.g., #2F5233)"
    return
}

if ($SecondaryColor -notmatch '^#[0-9A-Fa-f]{6}$') {
    Write-Error "❌ SecondaryColor must be a valid hex color (e.g., #8FBC8F)"
    return
}

Write-Host "📡 Fetching data from Sessionize API..." -ForegroundColor Green

# Set default values for optional parameters - optimized path resolution
if (-not $OutputPath) { 
    # Default to output folder (relative to script location) - cache script directory
    $script:scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $projectRoot = Split-Path (Split-Path $script:scriptDir -Parent) -Parent
    $OutputPath = Join-Path $projectRoot "output\Schedule.html"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath) -and -not $OutputPath.Contains('\') -and -not $OutputPath.Contains('/')) {
    # OutputPath is just a filename - put it in the output folder
    $script:scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $projectRoot = Split-Path (Split-Path $script:scriptDir -Parent) -Parent
    $OutputPath = Join-Path $projectRoot "output\$OutputPath"
}
if (-not $RoomPrefix) { $RoomPrefix = "" }

# Handle LogoPath - support both relative and absolute paths - optimized with early returns
if ($LogoPath) {
    if ([System.IO.Path]::IsPathRooted($LogoPath)) {
        # LogoPath is already an absolute path - use as is
        $resolvedLogoPath = $LogoPath
    } else {
        # LogoPath is relative - resolve relative to script location or current directory
        if (-not $script:scriptDir) {
            $script:scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        $projectRoot = Split-Path (Split-Path $script:scriptDir -Parent) -Parent
        
        # Try relative to project root first (common case for assets/images/logo.png)
        $projectRelativePath = Join-Path $projectRoot $LogoPath
        if (Test-Path $projectRelativePath -PathType Leaf) {
            $resolvedLogoPath = $projectRelativePath
        } else {
            # Fall back to current directory
            $resolvedLogoPath = Join-Path (Get-Location) $LogoPath
        }
    }
    
    # Verify the logo file exists
    if (-not (Test-Path $resolvedLogoPath -PathType Leaf)) {
        Write-Warning "Logo file not found at: $resolvedLogoPath"
        Write-Host "   The schedule will be generated without a logo." -ForegroundColor Yellow
        $LogoPath = $null
    } else {
        $LogoPath = $resolvedLogoPath
        Write-Host "Using logo: $LogoPath" -ForegroundColor Green
    }
}

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
$allDayPages = [System.Collections.Generic.List[string]]::new()
foreach ($currentDay in $daysToProcess) {
    $dayName = ([DateTime]$currentDay.date).ToString("dddd, MMMM dd, yyyy")
    
    Write-Host "📅 Processing $dayName..." -ForegroundColor Yellow
    
    $timeSlots = Get-TimeSlots -dayData $currentDay
    $specialEvents = Get-SpecialEvents -dayData $currentDay
    
    # Get all rooms for this day (excluding service rooms like Atrium) - optimized filtering
    $allRooms = $currentDay.rooms | Where-Object { 
        $_.name -notin @("Atrium") -and 
        $_.name -notmatch "Registration|Check.?in|Lobby" 
    } | Sort-Object name
    
    if ($allRooms.Count -eq 0) {
        Write-Host "⚠️ No session rooms found for $dayName, skipping..." -ForegroundColor Yellow
        continue
    }
    
    Write-Host "🏢 Found $($allRooms.Count) rooms: $($allRooms.name -join ', ')" -ForegroundColor Cyan
    
    # Dynamically determine optimal room distribution based on content width
    $roomPages = Get-OptimalRoomDistribution -rooms $allRooms -pageSize $PageSize -roomPrefix $RoomPrefix
    
    Write-Host "� DEBUG: RoomPages count after function call: $($roomPages.Count)" -ForegroundColor Magenta

    
    Write-Host "�📄 Generating $($roomPages.Count) pages for $dayName" -ForegroundColor Green
    
    for ($pageIndex = 0; $pageIndex -lt $roomPages.Count; $pageIndex++) {
        $currentPageRooms = $roomPages[$pageIndex].Rooms
        $isFirstPage = $pageIndex -eq 0
        $isLastPage = $pageIndex -eq ($roomPages.Count - 1)
        
        Write-Host "   � Page $($pageIndex + 1): $($currentPageRooms.name -join ', ')" -ForegroundColor White
        
        # Don't show day title if filtering for specific date, or if not the first page
        $pageTitle = if ($EventDateFilter -or -not $isFirstPage) { $null } else { $dayName }
        
        $pageHtml = New-TimeSlotGrid -dayData $currentDay -dayTitle $pageTitle -roomsToInclude $currentPageRooms -timeSlots $timeSlots -specialEvents $specialEvents -roomPrefix $RoomPrefix -EventName $EventName -EventDate $EventDate -LocationName $LocationName -Website $Website -LogoPath $LogoPath -AppUrl $AppUrl -IncludeHeader $isFirstPage
        $allDayPages.Add($pageHtml)
        
        # Add blank page after last page of this day if it has an odd number of pages and there are more days to process
        if ($isLastPage -and $roomPages.Count % 2 -eq 1 -and $currentDay -ne $daysToProcess[-1]) {
            $blankPageHtml = @"
<div class="day-section">
    <div style="text-align: center; padding-top: 200px; font-size: 16px; color: #666;">
        <div style="margin-bottom: 20px;">📄 This page intentionally left blank</div>
        <div style="font-size: 12px;">For double-sided printing alignment</div>
    </div>
</div>
"@
            $allDayPages.Add($blankPageHtml)
            Write-Host "   📄 Added blank page for double-sided printing alignment" -ForegroundColor Gray
        }
    }
}

Write-Host "✅ Schedule analysis complete! Generated $($allDayPages.Count) pages total." -ForegroundColor Green

# Generate CSS with custom colors and page size
$css = New-ScheduleCSS -PageSize $PageSize -Orientation $Orientation -PrimaryColor $PrimaryColor -SecondaryColor $SecondaryColor

# Generate HTML content using StringBuilder for better performance
$contentBuilder = [System.Text.StringBuilder]::new(32768)
[void]$contentBuilder.AppendLine(@"
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
"@)

# Add all processed day pages
foreach ($pageHtml in $allDayPages) {
    [void]$contentBuilder.Append($pageHtml)
}

# Add footer
[void]$contentBuilder.AppendLine(@"
</body>
</html>
"@)

$htmlContent = $contentBuilder.ToString()

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
    
    # Generate PDF if requested
    if ($GeneratePDF) {
        Write-Host "`n🔄 Generating PDF..." -ForegroundColor Yellow
        
        # Determine PDF path
        $pdfPath = $fullPath -replace '\.html$', '.pdf'
        
        # Try to find Microsoft Edge
        $edgePaths = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
            "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe"
        )
        
        $edgePath = $null
        foreach ($path in $edgePaths) {
            if (Test-Path $path) {
                $edgePath = $path
                break
            }
        }
        
        if ($edgePath) {
            try {
                # Generate PDF using Edge headless mode
                $null = & $edgePath --headless=new --print-to-pdf="$pdfPath" --no-margins "file:///$fullPath" --disable-gpu --disable-extensions --no-pdf-header-footer 2>&1
                Write-Host "✅ PDF generated successfully!" -ForegroundColor Green
                Write-Host "📄 PDF saved to: $pdfPath" -ForegroundColor Gray
            } catch {
                Write-Host "⚠️ Warning: Could not generate PDF. HTML file available at: $fullPath" -ForegroundColor Yellow
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "⚠️ Warning: Microsoft Edge not found. HTML file available at: $fullPath" -ForegroundColor Yellow
            Write-Host "You can manually convert the HTML to PDF using your preferred method." -ForegroundColor Yellow
        }
    }
    
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
    if ($GeneratePDF -and (Test-Path ($fullPath -replace '\.html$', '.pdf'))) {
        $openFile = Read-Host "`nWould you like to open the PDF file now? (y/n)"
        if ($openFile -eq 'y' -or $openFile -eq 'Y') {
            Start-Process ($fullPath -replace '\.html$', '.pdf')
        }
    } else {
        $openFile = Read-Host "`nWould you like to open the HTML file now? (y/n)"
        if ($openFile -eq 'y' -or $openFile -eq 'Y') {
            Start-Process $fullPath
        }
    }
    
} catch {
    Write-Error "❌ Failed to write HTML file: $_"
}

Write-Host "`n🎉 Schedule generation complete!" -ForegroundColor Green