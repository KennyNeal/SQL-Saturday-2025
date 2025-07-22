<#
.SYNOPSIS
    Generates and saves QR codes for arbitrary text using QRCoder.dll.

.DESCRIPTION
    This script prompts for text input, generates a QR code using QRCoder.dll, and saves it as a PNG file.

.PARAMETER Text
    The text to encode in the QR code. If not provided, prompts interactively.

.PARAMETER OutputPath
    The path to save the PNG file. If not provided, saves as QRCode.png in the current directory.

.EXAMPLE
    .\Generate-QRCode.ps1 -Text "Hello World" -OutputPath "C:\Temp\HelloQR.png"

.NOTES
    Requires QRCoder.dll in lib\QRCoder.dll relative to script location.
#>

param(
    [string]$Text,
    [string]$OutputPath
)

# Use script location to find QRCoder.dll
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)
$qrcoderPath = Join-Path $projectRoot 'lib\QRCoder.dll'

if (!(Test-Path $qrcoderPath)) {
    Write-Host "QRCoder.dll not found at $qrcoderPath" -ForegroundColor Red
    exit 1
}

Add-Type -Path $qrcoderPath

if (-not $Text) {
    $Text = Read-Host "Enter text to encode in QR code"
}

if (-not $OutputPath) {
    $OutputPath = Join-Path (Get-Location) "QRCode.png"
}

function GenerateQRCodePng {
    param(
        [string]$data,
        [string]$filePath,
        [int]$pixelSize = 30,
        $eccLevel = [QRCoder.QRCodeGenerator+ECCLevel]::L
    )
    $qrGenerator = New-Object QRCoder.QRCodeGenerator
    $qrData = $qrGenerator.CreateQrCode($data, $eccLevel)
    $qrCode = New-Object QRCoder.QRCode($qrData)
    $bitmap = $qrCode.GetGraphic($pixelSize)
    $bitmap.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    $qrCode.Dispose()
    $qrGenerator.Dispose()
}

try {
    GenerateQRCodePng -data $Text -filePath $OutputPath
    Write-Host "QR code saved to $OutputPath" -ForegroundColor Green
} catch {
    Write-Host "Error generating QR code: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
