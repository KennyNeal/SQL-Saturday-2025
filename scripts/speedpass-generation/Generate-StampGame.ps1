<#
.SYNOPSIS
    Generates a printable Stamp Game sheet for SQL Saturday using sponsor logos.
.DESCRIPTION
    This script creates a grid of sponsor logos (from Raffle folder, alphabetically, plus GON-navy-logo.png last),
    adds instructions and a Name field, and generates a PDF using Edge headless mode.
.OUTPUTS
    PDF file is generated in assets\documents\Stamp-Game-2025.pdf
.NOTES
    Author: SQL Saturday Team
    Prerequisite: PowerShell 5.1+, Microsoft Edge browser
#>

# Paths
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)
$raffleFolder = Join-Path $projectRoot "assets\images\Sponsor Logos\Raffle"
$gonLogo = Join-Path $projectRoot "assets\images\Sponsor Logos\GON-navy-logo.png"
$sqlSatLogo = Join-Path $projectRoot "assets\images\SQL_2025.png"
$outputFolder = Join-Path $projectRoot "assets\documents"
$outputPdf = Join-Path $outputFolder "Stamp-Game-2025.pdf"
$outputHtml = Join-Path $outputFolder "Stamp-Game-2025.html"

# Get and sort logo files
$logoFiles = Get-ChildItem -Path $raffleFolder | Where-Object { $_.Extension -match '\.(png|jpg|jpeg)$' } | Sort-Object Name | ForEach-Object { $_.FullName }

# Add GON logo to the raffle logos first
$logoFiles += $gonLogo

# Calculate center position for a 3-column grid
$totalLogos = $logoFiles.Count + 1  # +1 for SQL Saturday logo
$gridRows = [math]::Ceiling($totalLogos / 3)
$centerPosition = [math]::Floor($totalLogos / 2)

# Insert SQL Saturday logo at center position
$finalLogos = @()
for ($i = 0; $i -lt $totalLogos; $i++) {
    if ($i -eq $centerPosition) {
        $finalLogos += $sqlSatLogo
    } else {
        $logoIndex = if ($i -lt $centerPosition) { $i } else { $i - 1 }
        $finalLogos += $logoFiles[$logoIndex]
    }
}

$logoFiles = $finalLogos

# Preload sponsor logos as base64
$sponsorLogos = @()
foreach ($logoPath in $logoFiles) {
    $logoBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($logoPath))
    $ext = [System.IO.Path]::GetExtension($logoPath).Replace(".","")
    $sponsorLogos += @{ base64 = $logoBase64; ext = $ext; name = [System.IO.Path]::GetFileNameWithoutExtension($logoPath) }
}

# PDF grid settings
$gridCols = 3
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
    $html += "<div class='cell'><img class='logo-img' src='data:image/$($logo.ext);base64,$($logo.base64)' alt='$($logo.name)' /></div>"
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
    $html += "<div class='cell'><img class='logo-img' src='data:image/$($logo.ext);base64,$($logo.base64)' alt='$($logo.name)' /></div>"
}

$html += "</div></div></div></body></html>"

# Save HTML
Set-Content -Path $outputHtml -Value $html -Encoding UTF8

# Generate PDF using Edge headless mode
$edgePath = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
$null = & $edgePath --headless=new --print-to-pdf="$outputPdf" --no-margins "file:///$outputHtml" --disable-gpu --disable-extensions --no-pdf-header-footer 2>&1

Write-Host "Stamp Game PDF generated: $outputPdf" -ForegroundColor Green
