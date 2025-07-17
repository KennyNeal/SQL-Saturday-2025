<#
.SYNOPSIS
    Generates a printable Stamp Game sheet for SQL Saturday using sponsor logos.

.DESCRIPTION
    This script creates a grid of sponsor logos with customizable layout options,
    adds instructions and a Name field, and generates a PDF using Edge headless mode.

.PARAMETER RaffleFolder
    Path to folder containing raffle sponsor logos. Defaults to assets\images\Sponsor Logos\Raffle

.PARAMETER CenterLogo
    Path to logo that should be placed in the center of the grid. Defaults to SQL Saturday logo.

.PARAMETER AdditionalLogos
    Array of paths to additional logos to include in the grid (e.g., GON logo)

.PARAMETER AdditionalLogoPlacement
    Where to place additional logos: 'End' (after raffle logos), 'Alphabetical' (sorted with raffle logos), or 'Beginning' (before raffle logos). Default is 'End'.

.PARAMETER GridColumns
    Number of columns in the grid. Defaults to 3.

.OUTPUTS
    PDF file is generated in assets\documents\Stamp-Game-2025.pdf

.EXAMPLE
    .\Generate-StampGame.ps1
    Generates stamp game with default settings.

.EXAMPLE
    .\Generate-StampGame.ps1 -GridColumns 4 -AdditionalLogos @("C:\path\to\extra\logo.png")
    Generates stamp game with 4 columns and an extra logo.

.EXAMPLE
    .\Generate-StampGame.ps1 -AdditionalLogos @("C:\path\to\gon.png") -AdditionalLogoPlacement "Alphabetical"
    Generates stamp game with GON logo sorted alphabetically with other logos.

.NOTES
    Author: SQL Saturday Team
    Prerequisite: PowerShell 5.1+, Microsoft Edge browser
#>

param(
    [string]$RaffleFolder,
    [string]$CenterLogo,
    [string[]]$AdditionalLogos = @(),
    [ValidateSet('End', 'Alphabetical', 'Beginning')]
    [string]$AdditionalLogoPlacement = 'End',
    [int]$GridColumns = 3
)

# Paths
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)

# Set default paths if not provided
if (-not $RaffleFolder) {
    $RaffleFolder = Join-Path $projectRoot "assets\images\Sponsor Logos\Raffle"
}
if (-not $CenterLogo) {
    $CenterLogo = Join-Path $projectRoot "assets\images\SQL_2025.png"
}

$outputFolder = Join-Path $projectRoot "assets\documents"
$outputPdf = Join-Path $outputFolder "Stamp-Game-2025.pdf"
$outputHtml = Join-Path $outputFolder "Stamp-Game-2025.html"

# Get and sort logo files
$logoFiles = Get-ChildItem -Path $RaffleFolder | Where-Object { $_.Extension -match '\.(png|jpg|jpeg)$' } | Sort-Object Name | ForEach-Object { $_.FullName }

# Handle additional logos based on placement preference
switch ($AdditionalLogoPlacement) {
    'Beginning' {
        $logoFiles = $AdditionalLogos + $logoFiles
    }
    'Alphabetical' {
        # Combine all logos and sort alphabetically
        $allLogos = $logoFiles + $AdditionalLogos
        $logoFiles = $allLogos | Sort-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) }
    }
    'End' {
        $logoFiles += $AdditionalLogos
    }
}

# Calculate grid layout
$totalLogosWithCenter = $logoFiles.Count + 1  # +1 for center logo
$gridRows = [math]::Ceiling($totalLogosWithCenter / $GridColumns)
$totalCells = $gridRows * $GridColumns

# Calculate center position
$centerPosition = [math]::Floor($totalCells / 2)

# Build final logo array with center logo and fill empty cells
$finalLogos = @()
$logoIndex = 0

for ($i = 0; $i -lt $totalCells; $i++) {
    if ($i -eq $centerPosition) {
        # Place center logo
        $finalLogos += $CenterLogo
    } elseif ($logoIndex -lt $logoFiles.Count) {
        # Place regular logos
        $finalLogos += $logoFiles[$logoIndex]
        $logoIndex++
    } else {
        # Fill remaining cells with black squares
        $finalLogos += "BLACK_SQUARE"
    }
}

$logoFiles = $finalLogos

# Preload sponsor logos as base64
$sponsorLogos = @()
foreach ($logoPath in $logoFiles) {
    if ($logoPath -eq "BLACK_SQUARE") {
        # Create black square data
        $sponsorLogos += @{ base64 = ""; ext = ""; name = "BLACK_SQUARE"; isBlackSquare = $true }
    } else {
        $logoBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($logoPath))
        $ext = [System.IO.Path]::GetExtension($logoPath).Replace(".","")
        $sponsorLogos += @{ base64 = $logoBase64; ext = $ext; name = [System.IO.Path]::GetFileNameWithoutExtension($logoPath); isBlackSquare = $false }
    }
}

# PDF grid settings
$gridCols = $GridColumns
$gridRows = [math]::Ceiling($sponsorLogos.Count / $gridCols)

# Build HTML
$html = @"
<html><head>
<style>
@page {
  size: letter landscape;
  margin: 0.25in;
}
body { font-family: Arial; margin: 0; }
.page { display: flex; flex-direction: row; height: 100vh; gap: 0.5in; }
.stamp-sheet { flex: 1; }
.header { font-size: 12pt; font-weight: bold; margin-bottom: 0.1in; }
.instructions { font-size: 11pt; margin-bottom: 0.1in; }
.name-field { font-size: 11pt; margin-bottom: 0.2in; }
.grid { display: grid; grid-template-columns: repeat($gridCols, 2in); grid-gap: 0in; }
.cell { width: 2in; height: 1.3in; border: 1px solid #333; display: flex; align-items: center; justify-content: center; background: #fff; }
.logo-img { max-width: 1.8in; max-height: 1.1in; object-fit: contain; }
</style>
</head><body>
<div class="page">
<div class="stamp-sheet">
<div class="instructions">Get a stamp from each sponsor and return your completed form to the User Group table to enter the grand prize drawing.</div>
<div class="header">YOU MUST BE PRESENT TO WIN</div>
<div class="name-field">Name: ____________________________________________</div>
<div class="grid">
"@

# Add logo cells for first copy
foreach ($logo in $sponsorLogos) {
    if ($logo.isBlackSquare) {
        $html += "<div class='cell' style='background: #000;'></div>"
    } else {
        $html += "<div class='cell'><img class='logo-img' src='data:image/$($logo.ext);base64,$($logo.base64)' alt='$($logo.name)' /></div>"
    }
}

$html += @"
</div>
</div>
<div class="stamp-sheet">
<div class="instructions">Get a stamp from each sponsor and return your completed form to the User Group table to enter the grand prize drawing.</div>
<div class="header">YOU MUST BE PRESENT TO WIN</div>
<div class="name-field">Name: ____________________________________________</div>
<div class="grid">
"@

# Add logo cells for second copy
foreach ($logo in $sponsorLogos) {
    if ($logo.isBlackSquare) {
        $html += "<div class='cell' style='background: #000;'></div>"
    } else {
        $html += "<div class='cell'><img class='logo-img' src='data:image/$($logo.ext);base64,$($logo.base64)' alt='$($logo.name)' /></div>"
    }
}

$html += "</div></div></div></body></html>"

# Save HTML
Set-Content -Path $outputHtml -Value $html -Encoding UTF8

# Generate PDF using Edge headless mode
$edgePath = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
$null = & $edgePath --headless=new --print-to-pdf="$outputPdf" --no-margins "file:///$outputHtml" --disable-gpu --disable-extensions --no-pdf-header-footer 2>&1

Write-Host "Stamp Game PDF generated: $outputPdf" -ForegroundColor Green
