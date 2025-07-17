<#
.SYNOPSIS
    Generates speedpasses for SQL Saturday attendees.

.DESCRIPTION
    This script generates speedpasses for SQL Saturday attendees by retrieving attendee data from the database
    and creating PDF speedpasses with admission tickets, raffle tickets, and name tags. The script can generate
    speedpasses for all unprinted attendees or for specific individuals.

.PARAMETER FirstName
    First name of the attendee to generate speedpass for. Must be used with -LastName.

.PARAMETER LastName
    Last name of the attendee to generate speedpass for. Must be used with -FirstName.

.PARAMETER Email
    Email address of the attendee to generate speedpass for.

.PARAMETER Force
    Overwrite existing speedpasses. Without this switch, only new/unprinted speedpasses will be generated.

.EXAMPLE
    .\Generate-SpeedPasses.ps1
    Generates all unprinted speedpasses.

.EXAMPLE
    .\Generate-SpeedPasses.ps1 -FirstName "John" -LastName "Doe"
    Generates speedpass for John Doe.

.EXAMPLE
    .\Generate-SpeedPasses.ps1 -Email "john.doe@example.com"
    Generates speedpass for the attendee with the specified email address.

.EXAMPLE
    .\Generate-SpeedPasses.ps1 -FirstName "Jane" -LastName "Smith" -Force
    Regenerates speedpass for Jane Smith, overwriting any existing speedpass.

.EXAMPLE
    .\Generate-SpeedPasses.ps1 -Force
    Regenerates all speedpasses, overwriting existing ones.

.INPUTS
    None. You cannot pipe objects to this script.

.OUTPUTS
    PDF files are generated in the output\speedpasses folder.
    Raw QR code images are stored in output\speedpasses\raw folder.

.NOTES
    File Name      : Generate-SpeedPasses.ps1
    Author         : SQL Saturday Team
    Prerequisite   : PowerShell 5.1 or later, Microsoft Edge browser
    Requirements   : SQL Server database with attendee data
    
    The script uses Microsoft Edge in headless mode to generate PDFs from HTML.
    QR codes are generated using the qrserver.com API.

.LINK
    https://github.com/KennyNeal/SQL-Saturday-2025
#>

param(
    [string]$FirstName,
    [string]$LastName,
    [string]$Email,
    [switch]$Force
)

# CONFIGURATION
$connectionString = "Server=localhost\SQLEXPRESS;Database=SQLSaturday;Integrated Security=SSPI;"
$baseQuery = "SELECT First_Name, Last_Name, Email, Job_Title, Company, Lunch_Type, Barcode, vCard FROM dbo.AttendeesGetUnPrintedOrders"

# Use script location to find project root
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)

# Paths - Updated for new project structure
$sqlSatLogoPath = Join-Path $projectRoot "assets\images\SQL_2025.png"
$sponsorFolder = Join-Path $projectRoot "assets\images\Sponsor Logos\Raffle"
$outputFolder = Join-Path $projectRoot "output\speedpasses"
$rawFolder = Join-Path $outputFolder "raw"

# Ensure folders exist
if (!(Test-Path $outputFolder)) { New-Item -ItemType Directory -Path $outputFolder }
if (!(Test-Path $rawFolder)) { New-Item -ItemType Directory -Path $rawFolder }

# Load SQLSatBR logo
$sqlSatLogoBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($sqlSatLogoPath))

# Preload sponsor logos as base64
$sponsorLogos = @{}
Get-ChildItem -Path $sponsorFolder | Where-Object { $_.Extension -match '\.(png|jpg|jpeg)$' } | Sort-Object Name | ForEach-Object {
    $logoBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName))
    $ext = $_.Extension.Replace(".", "")
    $sponsorLogos[$_.Name] = @{ base64 = $logoBase64; ext = $ext }
}

# Function to build query based on parameters
function Get-AttendeeQuery {
    param(
        [string]$FirstName,
        [string]$LastName,
        [string]$Email,
        [switch]$Force
    )
    
    # If specific attendees are requested (by name or email), use the main Attendees table
    # since they might already be printed and won't be in the UnPrintedOrders view
    if ($FirstName -or $LastName -or $Email) {
        $query = "SELECT First_Name, Last_Name, Email, Job_Title, Company, Lunch_Type, Barcode, vCard FROM dbo.AttendeesWithVCard"
    } elseif ($Force) {
        # Force all attendees - use main table
        $query = "SELECT First_Name, Last_Name, Email, Job_Title, Company, Lunch_Type, Barcode, vCard FROM dbo.AttendeesWithVCard"
    } else {
        # Default behavior - only unprinted
        $query = $baseQuery
    }
    
    $whereClause = @()
    
    if ($FirstName) {
        $whereClause += "First_Name = '$($FirstName.Replace("'", "''"))'"
    }
    if ($LastName) {
        $whereClause += "Last_Name = '$($LastName.Replace("'", "''"))'"
    }
    if ($Email) {
        $whereClause += "Email = '$($Email.Replace("'", "''"))'"
    }
    
    if ($whereClause.Count -gt 0) {
        $query += " WHERE " + ($whereClause -join " AND ")
    }
    
    return $query
}

# Function to generate speedpass for an attendee
function New-AttendeeSpeedpass {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Attendee,
        
        [Parameter(Mandatory)]
        [hashtable]$SponsorLogos,
        
        [Parameter(Mandatory)]
        [string]$SqlSatLogoBase64,
        
        [Parameter(Mandatory)]
        [string]$OutputFolder,
        
        [Parameter(Mandatory)]
        [string]$RawFolder,
        
        [switch]$Force
    )
    
    $fullName = "$($Attendee.FirstName) $($Attendee.LastName)"
    $nameLastFirst = "$($Attendee.LastName), $($Attendee.FirstName)"
    $safeName = $nameLastFirst -replace '\s', '_' -replace '[^\w]', ''

    # Check if speedpass already exists (unless Force is used)
    $pdfPath = Join-Path $OutputFolder "$safeName.pdf"
    if ((Test-Path $pdfPath) -and !$Force) {
        Write-Host "Speedpass for $fullName already exists. Use -Force to regenerate." -ForegroundColor Yellow
        return $false
    }

    # Generate QR codes
    $emailQRPath = Join-Path $RawFolder "$safeName-emailQR.png"
    $orderQRPath = Join-Path $RawFolder "$safeName-orderQR.png"
    $vCardQRPath = Join-Path $RawFolder "$safeName-vCardQR.png"

    if (!(Test-Path $emailQRPath) -or $Force) {
        Invoke-WebRequest "https://api.qrserver.com/v1/create-qr-code/?data=$([System.Web.HttpUtility]::UrlEncode($Attendee.Email))&size=150x150" -OutFile $emailQRPath
    }
    if (!(Test-Path $orderQRPath) -or $Force) {
        Invoke-WebRequest "https://api.qrserver.com/v1/create-qr-code/?data=$([System.Web.HttpUtility]::UrlEncode($Attendee.Barcode))&size=150x150" -OutFile $orderQRPath
    }
    if (!(Test-Path $vCardQRPath) -or $Force) {
        Invoke-WebRequest "https://api.qrserver.com/v1/create-qr-code/?data=$([System.Web.HttpUtility]::UrlEncode($Attendee.vCardText))&size=150x150" -OutFile $vCardQRPath
    }

    $emailQRBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($emailQRPath))
    $orderQRBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($orderQRPath))
    $vCardQRBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($vCardQRPath))

    # Build HTML
    $html = @"
<html><head>
<style>
body { margin: 0; padding: 0; font-family: Arial; }

@page {
  size: Letter;
  margin: 0.35in;
}

.sheet {
  display: grid;
  grid-template-columns: repeat(2, 3.5in);
  grid-template-rows: repeat(5, 2in);
  padding: 0.25in;
}
.card {
  width: 3.5in;
  height: 2in;
  border: 1px dashed #ccc;
  box-sizing: border-box;
  display: flex;
  flex-direction: row;
  justify-content: space-between;
  align-items: stretch;
  position: relative;
  padding: 0.5in 0.25in 0.2in 0.25in;
  font-size: 9pt;
  break-inside: avoid;
}
.left {
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  align-items: flex-start;
  flex: 1 1 0;
  padding-right: 0.2in;
  min-width: 1.5in;
  /* allow it to grow vertically */
}
.footer { 
  margin-top: auto; 
  font-size: 9pt; 
  text-align: center; /* Center the footer text */
}
.logo {
  width: 1.5in;
  height: 0.6in;
  object-fit: contain;
  margin-bottom: 0.05in;
}
.qr-block {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
  width: 1.4in;
  min-width: 1.2in;
}
.qr {
  width: 1.2in;
  height: 1.2in;
  object-fit: contain;
  margin-bottom: 0.05in;
}
.card.nametag {
  flex-direction: column;
  justify-content: flex-start;
  align-items: center;
  text-align: center;
  font-size: 10pt;
  padding: 0.1in;
}
.nametag-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: 100%;
  margin-bottom: 0.1in;
}
.nametag .logo, .nametag .qr {
  width: 1in;
  height: 1in;
  object-fit: contain;
}
.admission { font-size: 10pt; font-weight: bold; }
.fit-text {
  width: 100%;
  height: 1.2in;
  overflow: hidden;
  line-height: 1.2;
  white-space: normal;
  word-wrap: break-word;
}
.ticket-banner {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  text-align: center;
  font-size: 10pt;
  font-weight: bold;
  padding-top: 0.05in;
}
.raffle-footer {
  margin-top: auto;
  text-align: center;
  font-size: 9pt;
}
.raffle-name {
  font-weight: bold;
  margin-top: 0.05in;
  text-align: left;
  font-size: 10pt;
  word-break: break-word;
  line-height: 1.1;
}
.email-text {
  font-size: 9pt;
  text-align: left;
  word-break: break-all;
  margin-top: 0.02in;
  line-height: 1.1;
  /* REMOVE max-width and white-space */
}
</style>
</head><body><div class="sheet">
"@

    # Header card
    $html += @"
<div class="card">
 <div class="ticket-banner">#SQLSatBR 2025</div>
  <div class="left">
    <div class="admission">Admission Ticket</div>
    <strong>$nameLastFirst</strong><br/>
    Lunch: $($Attendee.LunchType)<br/>
    <div class="footer">SQL Saturday Baton Rouge 2025</div>
  </div>
  <img src="data:image/png;base64,$orderQRBase64" class="qr" />
</div>
"@

    # Raffle cards
    foreach ($logo in $SponsorLogos.GetEnumerator()) {
        $logoBase64 = $logo.Value.base64
        $ext = $logo.Value.ext
        $html += @"
<div class="card">
  <div class="ticket-banner">#SQLSatBR 2025 - Raffle Ticket</div>
  <div class="left">
    <img src="data:image/$ext;base64,$logoBase64" class="logo" />
    <div class="raffle-name">$fullName</div>
    <div class="email-text">$($Attendee.Email)</div>
  </div>
  <div class="qr-block">
    <img src="data:image/png;base64,$vCardQRBase64" class="qr" />
  </div>
</div>
"@
    }
    # Nametag
    $html += @"
<div class="card nametag">
  <div class="nametag-top">
    <img src="data:image/png;base64,$SqlSatLogoBase64" class="logo" />
    <img src="data:image/png;base64,$emailQRBase64" class="qr" />
  </div>
  <div class="fit-text"><strong>$fullName</strong><br/>$($Attendee.JobTitle)<br/>$($Attendee.Company)</div>
</div>
</div>
<script>
function fitTextToContainer(el) {
  let fontSize = 20;
  el.style.fontSize = fontSize + "pt";
  while ((el.scrollWidth > el.clientWidth || el.scrollHeight > el.clientHeight) && fontSize > 6) {
    fontSize -= 0.5;
    el.style.fontSize = fontSize + "pt";
  }
}

function fitEmailText(el) {
  let fontSize = 9;
  el.style.fontSize = fontSize + "pt";
  
  // Check if text wraps to multiple lines
  const lineHeight = parseFloat(window.getComputedStyle(el).lineHeight);
  const height = el.offsetHeight;
  const lines = Math.round(height / lineHeight);
  
  // If more than 1 line, reduce font size
  while (lines > 1 && fontSize > 6) {
    fontSize -= 0.5;
    el.style.fontSize = fontSize + "pt";
    const newHeight = el.offsetHeight;
    const newLines = Math.round(newHeight / lineHeight);
    if (newLines <= 1) break;
  }
}

function fitNameText(el) {
  let fontSize = 10;
  el.style.fontSize = fontSize + "pt";
  
  // Check if text wraps to multiple lines
  const lineHeight = parseFloat(window.getComputedStyle(el).lineHeight);
  const height = el.offsetHeight;
  const lines = Math.round(height / lineHeight);
  
  // If more than 1 line, reduce font size
  while (lines > 1 && fontSize > 7) {
    fontSize -= 0.5;
    el.style.fontSize = fontSize + "pt";
    const newHeight = el.offsetHeight;
    const newLines = Math.round(newHeight / lineHeight);
    if (newLines <= 1) break;
  }
}

window.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".fit-text").forEach(el => fitTextToContainer(el));
  document.querySelectorAll(".email-text").forEach(el => fitEmailText(el));
  document.querySelectorAll(".raffle-name").forEach(el => fitNameText(el));
});
</script>
</body></html>
"@

    # Save and generate PDF using Edge headless mode
    $htmlPath = Join-Path $OutputFolder "$safeName.html"
    $pdfPath = Join-Path $OutputFolder "$safeName.pdf"
    Set-Content -Path $htmlPath -Value $html -Encoding UTF8

    # Suppress Edge output by redirecting to null
    $edgePath = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    $null = & $edgePath --headless=new --print-to-pdf="$pdfPath" --no-margins "file:///$htmlPath" --disable-gpu --disable-extensions --no-pdf-header-footer 2>&1
    
    Write-Host "Generated SpeedPass for $fullName" -ForegroundColor Green
    Start-Sleep -Seconds 5  # Add this line to throttle PDF generation
    return $true
}

# Main execution logic
# Validate parameters
if ($FirstName -and !$LastName) {
    Write-Host "Error: When specifying -FirstName, you must also specify -LastName" -ForegroundColor Red
    exit 1
}
if ($LastName -and !$FirstName) {
    Write-Host "Error: When specifying -LastName, you must also specify -FirstName" -ForegroundColor Red
    exit 1
}

# Build query based on parameters
$query = Get-AttendeeQuery -FirstName $FirstName -LastName $LastName -Email $Email -Force:$Force

Write-Host "Executing query: $query" -ForegroundColor Cyan

# Get attendees
try {
    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $connection.Open()
    $reader = $command.ExecuteReader()
    $attendees = @()
    while ($reader.Read()) {
        $attendees += [PSCustomObject]@{
            FirstName = $reader["First_Name"]
            LastName  = $reader["Last_Name"]
            Email     = $reader["Email"]
            JobTitle  = $reader["Job_Title"]
            Company   = $reader["Company"]
            LunchType = $reader["Lunch_Type"]
            Barcode   = $reader["Barcode"]
            vCardText = $reader["vCard"]
        }
    }
    $connection.Close()
} catch {
    Write-Host "Error connecting to database: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Check if any attendees were found
if ($attendees.Count -eq 0) {
    if ($FirstName -or $LastName -or $Email) {
        Write-Host "No attendees found matching the specified criteria." -ForegroundColor Yellow
    } else {
        Write-Host "No unprinted speedpasses found. Use -Force to regenerate all speedpasses." -ForegroundColor Yellow
    }
    exit 1
}

Write-Host "Found $($attendees.Count) attendee(s) to process" -ForegroundColor Green

# Process each attendee
$processed = 0
$skipped = 0
foreach ($attendee in $attendees) {
    $result = New-AttendeeSpeedpass -Attendee $attendee -SponsorLogos $sponsorLogos -SqlSatLogoBase64 $sqlSatLogoBase64 -OutputFolder $outputFolder -RawFolder $rawFolder -Force:$Force
    if ($result -ne $false) {
        $processed++
    } else {
        $skipped++
    }
}

# Summary
Write-Host "`n=== SPEEDPASS GENERATION SUMMARY ===" -ForegroundColor Green
Write-Host "Processed: $processed" -ForegroundColor Green
if ($skipped -gt 0) {
    Write-Host "Skipped: $skipped (already exist, use -Force to regenerate)" -ForegroundColor Yellow
}
Write-Host "Output folder: $outputFolder" -ForegroundColor Cyan