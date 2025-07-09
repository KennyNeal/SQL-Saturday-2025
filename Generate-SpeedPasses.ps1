# CONFIGURATION
$connectionString = "Server=localhost\SQLEXPRESS;Database=SQLSaturday;Integrated Security=SSPI;"
$query = "SELECT TOP 10 First_Name, Last_Name, Email, Job_Title, Company, Lunch_Type, Barcode, vCard FROM dbo.AttendeesGetUnPrintedOrders WHERE Last_Name = 'Neal'"

$BaseFolder = "C:\Users\kneal\OneDrive\Documents\SQL Saturday 2025"
# Paths
$sqlSatLogoPath = Join-Path $BaseFolder "Images\SQL_2025.png"
$sponsorFolder = Join-Path $BaseFolder "Images\Sponsor Logos\Raffle"
$outputFolder = Join-Path $BaseFolder "SpeedPass"
$rawFolder = Join-Path $outputFolder "raw"

# Ensure folders exist
if (!(Test-Path $outputFolder)) { New-Item -ItemType Directory -Path $outputFolder }
if (!(Test-Path $rawFolder)) { New-Item -ItemType Directory -Path $rawFolder }

# Load SQLSatBR logo
$sqlSatLogoBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($sqlSatLogoPath))

# Get attendees
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

# Loop through attendees
foreach ($a in $attendees) {
  $fullName = "$($a.FirstName) $($a.LastName)"
  $nameLastFirst = "$($a.LastName), $($a.FirstName)"
  $safeName = $nameLastFirst -replace '\s', '_' -replace '[^\w]', ''

  # Generate QR codes
  $emailQRPath = Join-Path $rawFolder "$safeName-emailQR.png"
  $orderQRPath = Join-Path $rawFolder "$safeName-orderQR.png"
  $vCardQRPath = Join-Path $rawFolder "$safeName-vCardQR.png"

  Invoke-WebRequest "https://api.qrserver.com/v1/create-qr-code/?data=$([System.Web.HttpUtility]::UrlEncode($a.Email))&size=150x150" -OutFile $emailQRPath
  Invoke-WebRequest "https://api.qrserver.com/v1/create-qr-code/?data=$([System.Web.HttpUtility]::UrlEncode($a.Barcode))&size=150x150" -OutFile $orderQRPath
  Invoke-WebRequest "https://api.qrserver.com/v1/create-qr-code/?data=$([System.Web.HttpUtility]::UrlEncode($a.vCardText))&size=150x150" -OutFile $vCardQRPath

  $emailQRBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($emailQRPath))
  $orderQRBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($orderQRPath))
  $vCardQRBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($vCardQRPath))

  # Build HTML
  $html = @"
<html><head>
<style>
body { margin: 0; padding: 0; font-family: Arial; }

.sheet {
  display: grid;
  grid-template-columns: repeat(2, 3.5in);
  grid-template-rows: repeat(5, 2in);
  gap: 0.2in;
  padding: 0.5in;
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
  padding: 0.4in 0.15in 0.1in 0.15in;
  font-size: 9pt;
}
.left {
  display: flex;
  flex-direction: column;
  justify-content: flex-start;
  align-items: center;
  flex: 1;
  padding-right: 0.2in;
}
.footer { margin-top: auto; font-size: 9pt; }
.logo {
  width: 1.5in;
  height: 0.6in;
  object-fit: contain;
  margin-bottom: 0.05in;
}
.qr {
  width: 1.2in;
  height: 1.2in;
  object-fit: contain;
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
    Lunch: $($a.LunchType)<br/>
    <div class="footer">SQL Saturday Baton Rouge 2025</div>
  </div>
  <img src="data:image/png;base64,$orderQRBase64" class="qr" />
</div>
"@

  # Raffle cards
  Get-ChildItem -Path $sponsorFolder | Where-Object { $_.Extension -match '\.(png|jpg|jpeg)$' } | Sort-Object Name | ForEach-Object {
    $logoBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName))
    $ext = $_.Extension.Replace(".", "")
    $html += @"
<div class="card">
  <div class="ticket-banner">#SQLSatBR 2025</div>
  <div class="left fit-text">
    <img src="data:image/$ext;base64,$logoBase64" class="logo" />
    <div class="raffle-footer">
      <strong>$fullName</strong><br/>$($a.Email)
    </div>
  </div>
  <img src="data:image/png;base64,$vCardQRBase64" class="qr" />
</div>
"@
  }
  # Nametag
  $html += @"
<div class="card nametag">
  <div class="nametag-top">
    <img src="data:image/png;base64,$sqlSatLogoBase64" class="logo" />
    <img src="data:image/png;base64,$emailQRBase64" class="qr" />
  </div>
  <div class="fit-text"><strong>$fullName</strong><br/>$($a.JobTitle)<br/>$($a.Company)</div>
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
window.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".fit-text").forEach(el => fitTextToContainer(el));
});
</script>
</body></html>
"@

  # Save and generate PDF using Chrome headless mode
  $htmlPath = Join-Path $outputFolder "$safeName.html"
  $pdfPath = Join-Path $outputFolder "$safeName.pdf"
  Set-Content -Path $htmlPath -Value $html -Encoding UTF8

  Start-Process -FilePath msedge.exe -ArgumentList @(
    "--headless=new",
    "--print-to-pdf=`"$pdfPath`"",
    "--no-margins",
    "`"file:///$htmlPath`"",
    "--disable-gpu",
    "--disable-extensions",
    "--no-pdf-header-footer"
  ) -Wait

  Write-Host "PDF generated for $fullName`: $pdfPath"
}