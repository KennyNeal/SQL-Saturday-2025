<#
.SYNOPSIS
Sends personalized SpeedPass emails to SQL Saturday attendees with PDF attachments.

.DESCRIPTION
This script fetches attendee information from a SQL Server database, validates PDF files,
and sends personalized emails with SpeedPass attachments. Includes WhatIf support for 
previewing operations before execution.

.PARAMETER WhatIf
Preview what emails would be sent without actually sending them or making database changes.

.PARAMETER ShowBanner
Include a warning banner in emails (useful for resend notifications).

.PARAMETER ConnectionString
SQL Server connection string. Defaults to localhost\SQLEXPRESS.

.PARAMETER OutputFolder
Path to folder containing PDF files. Defaults to current SpeedPass folder.

.PARAMETER CredPath
Path to encrypted Gmail credentials file. Defaults to standard location.

.PARAMETER DelaySeconds
Delay in seconds between each email. Defaults to 2 seconds.

.PARAMETER BatchSize
Number of emails to process in each batch. Defaults to 50.

.PARAMETER EmailType
Type of email to send: 'attendee' or 'volunteer'. Defaults to 'attendee'.

.EXAMPLE
.\Mailing.ps1 -WhatIf
Preview what emails would be sent without sending them.

.EXAMPLE
.\Mailing.ps1 -ShowBanner
Send emails with warning banner included.

.EXAMPLE
.\Mailing.ps1 -DelaySeconds 5 -BatchSize 25
Send emails with 5-second delays in batches of 25.

.NOTES
Requires Gmail app password stored in encrypted XML file.
Creates error logs and skipped lists in the output folder.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$ShowBanner = $false,
    [string]$ConnectionString = "Server=localhost\SQLEXPRESS;Database=SQLSaturday;Integrated Security=SSPI;",
    [string]$OutputFolder = "C:\Users\kneal\OneDrive\Documents\SQL Saturday 2025\SpeedPass",
    [string]$CredPath = "C:\Users\kneal\gmail-cred.xml",
    [int]$DelaySeconds = 2,
    [int]$BatchSize = 50,
    [ValidateSet("attendee", "volunteer")][string]$EmailType = "attendee",
    [string]$TestEmail = ""
)

# CONFIGURATION
$markEmailedProc = "dbo.AttendeesMarkAsEmailed"
$markBatchEmailedProc = "dbo.AttendeesMarkBatchAsEmailed"
$bannerHtml = "<p style='color: red; font-weight: bold;'>There was an issue with our first batch of emails. We're sorry if you have received this twice.</p>"

switch ($EmailType) {
    "attendee" {
        $getAttendeesQuery = "EXEC dbo.AttendeesGetForEmail"
        $subject = "See You at SQL Saturday Baton Rouge 2025!"
        $bodyTemplate = @"
$(if ($ShowBanner) { $bannerHtml } else { "" })
<p>Hi {{FirstName}},</p>
<p>Your personalized SpeedPass for SQL Saturday Baton Rouge 2025 is attached!</p>
<p><b>Please print your SpeedPass and bring it with you to the event.</b> This will help us check you in quickly and get you to the sessions and raffle tickets faster.</p>
<p>We still have seats available for both of our pre-conference sessions:</p>
<ul>
  <li>
    <b>Jumpstart Your Power BI Skills: A Hands on Workshop</b><br>
    <a href='https://www.sqlsatbr.com/precons#h.nlb272c3ff5i'>Register here</a>
  </li>
  <li>
    <b>Become immediately effective with PowerShell</b><br>
    <a href='https://www.sqlsatbr.com/precons#h.dg9pejggrn5z'>Register here</a>
  </li>
</ul>
<p>Interested in helping out?<br>
Sign up to volunteer here:<br>
<a href='https://www.signupgenius.com/go/4090C49AFAA2EA2FF2-57005830-sqlsaturday#/'>https://www.signupgenius.com/go/4090C49AFAA2EA2FF2-57005830-sqlsaturday#/</a>
</p>
<p>Please help us spread the word! Share our event on social media and invite your friends and colleagues.</p>
<p>We look forward to seeing you soon!</p>
<p>Best regards,<br>
The SQL Saturday Baton Rouge Team</p>
"@
    }
    "volunteer" {
        $getAttendeesQuery = @"
SELECT DISTINCT First_Name, Last_Name, Email
FROM SQLSaturday..Attendees
WHERE Are_you_willing_to_volunteer_during_the_event = 'Yes'
"@
        $subject = "Volunteer for SQL Saturday Baton Rouge 2025!"
        $bodyTemplate = @"
<p>Hi {{FirstName}},</p>
<p>Thank you for offering to volunteer at SQL Saturday Baton Rouge 2025!</p>
<p>Please sign up for a volunteer slot here:<br>
<a href='https://www.signupgenius.com/go/4090C49AFAA2EA2FF2-57005830-sqlsaturday#/'>Volunteer Signup</a>
</p>
<p>We appreciate your help and look forward to seeing you at the event!</p>
<p>Best regards,<br>
The SQL Saturday Baton Rouge Team</p>
"@
    }
}

# Validate paths and credentials
if (-not (Test-Path $CredPath)) {
    throw "Credential file not found: $CredPath"
}

if (-not (Test-Path $OutputFolder)) {
    throw "Output folder not found: $OutputFolder"
}

$cred = Import-Clixml -Path $CredPath
$from = $cred.UserName

Write-Host "=== SQL Saturday Email Sender ===" -ForegroundColor Cyan
if ($WhatIfPreference) {
    Write-Host "🔍 WHATIF MODE: No emails will be sent, no database changes will be made" -ForegroundColor Yellow
}
Write-Host "📁 Output Folder: $OutputFolder" -ForegroundColor Gray
Write-Host "📧 From: $from" -ForegroundColor Gray
Write-Host "🎛️  Banner Enabled: $ShowBanner" -ForegroundColor Gray
Write-Host "📬 Email Type: $EmailType" -ForegroundColor Gray

# FETCH ATTENDEE EMAILS
Write-Host "`n📊 Fetching attendees from database..." -ForegroundColor Green

try {
    $connection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
    $command = $connection.CreateCommand()
    $command.CommandText = $getAttendeesQuery
    $connection.Open()
    $reader = $command.ExecuteReader()
    $attendees = @()
    while ($reader.Read()) {
        $attendees += [PSCustomObject]@{
            FirstName = $reader["First_Name"]
            LastName  = $reader["Last_Name"]
            Email     = $reader["Email"]
            Barcode   = if ($null -ne $reader["Barcode"]) { $reader["Barcode"] } else { $null }
            OrderDate = if ($reader.PSObject.Properties.Match("Order_Date").Count -gt 0 -and $reader["Order_Date"] -ne [DBNull]::Value) { $reader["Order_Date"] } else { $null }
            JobTitle  = if ($reader.PSObject.Properties.Match("Job_Title").Count -gt 0 -and $reader["Job_Title"] -ne [DBNull]::Value) { $reader["Job_Title"] } else { "" }
            Company   = if ($reader.PSObject.Properties.Match("Company").Count -gt 0 -and $reader["Company"] -ne [DBNull]::Value) { $reader["Company"] } else { "" }
        }
    }
    $connection.Close()
    Write-Host "✅ Found $($attendees.Count) attendees to process" -ForegroundColor Green
    if ($attendees.Count -eq 0) {
        Write-Host "ℹ️  No attendees found. Exiting." -ForegroundColor Yellow
        return
    }
} catch {
    Write-Error "❌ Database error: $_"
    return
}

# After fetching attendees, filter for test mode
if ($TestEmail -and $TestEmail -ne "") {
    $attendees = $attendees | Where-Object { $_.Email -eq $TestEmail }
    Write-Host "✉️  TEST MODE: Only sending to $TestEmail" -ForegroundColor Yellow
}

# Validate PDF files and create processing summary
$validAttendees = @()
$missingPdfs = @()

Write-Host "`n🔍 Validating PDF files..." -ForegroundColor Green

foreach ($a in $attendees) {
    $nameLastFirst = "$($a.LastName), $($a.FirstName)"
    $safeName = $nameLastFirst -replace '\s', '_' -replace '[^\w]', ''
    $pdfPath = Join-Path $OutputFolder "$safeName.pdf"
    
    if (Test-Path $pdfPath) {
        $validAttendees += [PSCustomObject]@{
            Attendee = $a
            SafeName = $safeName
            PdfPath = $pdfPath
            NameLastFirst = $nameLastFirst
        }
    } else {
        $missingPdfs += $nameLastFirst
    }
}

Write-Host "✅ Valid PDFs found: $($validAttendees.Count)" -ForegroundColor Green
if ($missingPdfs.Count -gt 0) {
    Write-Host "⚠️  Missing PDFs: $($missingPdfs.Count)" -ForegroundColor Yellow
}

if ($WhatIfPreference) {
    Write-Host "`n📋 PREVIEW - Emails that would be sent:" -ForegroundColor Cyan
    $validAttendees | ForEach-Object { 
        Write-Host "  📧 $($_.Attendee.Email) ← $($_.SafeName).pdf" -ForegroundColor White
    }
    
    if ($missingPdfs.Count -gt 0) {
        Write-Host "`n⚠️  PREVIEW - Attendees that would be skipped (missing PDFs):" -ForegroundColor Yellow
        $missingPdfs | ForEach-Object { Write-Host "  ❌ $_" -ForegroundColor Red }
    }
    
    Write-Host "`n📊 SUMMARY:" -ForegroundColor Cyan
    Write-Host "  📧 Emails to send: $($validAttendees.Count)" -ForegroundColor White
    Write-Host "  ⚠️  Skipped (no PDF): $($missingPdfs.Count)" -ForegroundColor White
    Write-Host "  📂 Output folder: $OutputFolder" -ForegroundColor Gray
    Write-Host "`nTo actually send emails, run without -WhatIf parameter" -ForegroundColor Yellow
    return
}

# SEND EMAILS
if ($validAttendees.Count -gt 0) {
    Write-Host "`n📧 Starting email send process..." -ForegroundColor Green
    Write-Host "📦 Processing in batches of $BatchSize" -ForegroundColor Gray
    
    $successCount = 0
    $errorCount = 0
    $skippedCount = $missingPdfs.Count
    $errorLog = @()
    $emailedBarcodes = @()
    
    # Function to mark attendee as emailed in database
    function Set-AttendeeAsEmailed {
        param($Barcode, $ConnectionString)
        try {
            $markConn = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
            $markCmd = $markConn.CreateCommand()
            $markCmd.CommandText = $markEmailedProc
            $markCmd.CommandType = [System.Data.CommandType]::StoredProcedure
            $markCmd.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@Barcode", $Barcode))) | Out-Null
            $markConn.Open()
            $markCmd.ExecuteScalar() | Out-Null
            $markConn.Close()
            return $true
        } catch {
            Write-Host "  ⚠️  Database logging failed for $Barcode : $_" -ForegroundColor Yellow
            return $false
        }
    }
    
    # Function to batch mark attendees as emailed
    function Set-BatchAttendeesAsEmailed {
        param($BarcodeList, $ConnectionString)
        if ($BarcodeList.Count -eq 0) { return }
        
        try {
            $barcodeString = $BarcodeList -join ','
            $batchConn = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
            $batchCmd = $batchConn.CreateCommand()
            $batchCmd.CommandText = $markBatchEmailedProc
            $batchCmd.CommandType = [System.Data.CommandType]::StoredProcedure
            $batchCmd.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@BarcodeList", $barcodeString))) | Out-Null
            $batchConn.Open()
            $reader = $batchCmd.ExecuteReader()
            if ($reader.Read()) {
                $message = $reader["Message"]
                Write-Host "  📝 Batch update: $message" -ForegroundColor Gray
            }
            $batchConn.Close()
        } catch {
            Write-Host "  ⚠️  Batch database logging failed: $_" -ForegroundColor Yellow
        }
    }
    
    $smtp = "smtp.gmail.com"
    $port = 587
    
    # Process in batches to avoid overwhelming the SMTP server
    for ($i = 0; $i -lt $validAttendees.Count; $i += $BatchSize) {
        $batch = $validAttendees[$i..([Math]::Min($i + $BatchSize - 1, $validAttendees.Count - 1))]
        $batchNumber = [Math]::Floor($i / $BatchSize) + 1
        $totalBatches = [Math]::Ceiling($validAttendees.Count / $BatchSize)
        $batchEmailedBarcodes = @()
        
        Write-Host "`n📦 Processing batch $batchNumber of $totalBatches ($($batch.Count) emails)..." -ForegroundColor Cyan
        
        foreach ($item in $batch) {
            $a = $item.Attendee
            $body = $bodyTemplate -replace '{{FirstName}}', $a.FirstName
            
            try {
                if ($EmailType -eq "attendee") {
                    $subject = "See You at SQL Saturday Baton Rouge 2025!"
                    $body = $bodyTemplate -replace '{{FirstName}}', $a.FirstName
                    
                    Send-MailMessage -To $a.Email -From $from -Subject $subject -Body $body `
                        -SmtpServer $smtp -Port $port -UseSsl -Credential $cred -Attachments $item.PdfPath -BodyAsHtml -WarningAction SilentlyContinue
                } elseif ($EmailType -eq "volunteer") {
                    $subject = "Volunteer for SQL Saturday Baton Rouge 2025!"
                    $body = $bodyTemplate -replace '{{FirstName}}', $a.FirstName
                    
                    Send-MailMessage -To $a.Email -From $from -Subject $subject -Body $body `
                        -SmtpServer $smtp -Port $port -UseSsl -Credential $cred -BodyAsHtml -WarningAction SilentlyContinue
                }
                
                Write-Host "✅ Sent: $($item.SafeName).pdf ➝ $($a.Email)" -ForegroundColor Green
                
                # Add to batch for database logging
                $batchEmailedBarcodes += $a.Barcode
                $emailedBarcodes += $a.Barcode
                $successCount++
                
            } catch {
                $errorMessage = "Error sending to $($a.Email): $_"
                Write-Host "❌ $errorMessage" -ForegroundColor Red
                $errorLog += $errorMessage
                $errorCount++
            }
            
            # Delay between emails to be nice to the SMTP server
            if ($DelaySeconds -gt 0) {
                Start-Sleep -Seconds $DelaySeconds
            }
        }
        
        # Update database for successful emails in this batch
        if ($batchEmailedBarcodes.Count -gt 0 -and $EmailType -eq "attendee") {
            Set-BatchAttendeesAsEmailed -BarcodeList $batchEmailedBarcodes -ConnectionString $ConnectionString
        }
        
        # Longer delay between batches
        if ($i + $BatchSize -lt $validAttendees.Count) {
            Write-Host "⏳ Waiting before next batch..." -ForegroundColor Gray
            Start-Sleep -Seconds ($DelaySeconds * 2)
        }
    }
    
    # Final summary
    Write-Host "`n📊 FINAL SUMMARY:" -ForegroundColor Cyan
    Write-Host "✅ Successfully sent: $successCount emails" -ForegroundColor Green
    Write-Host "📝 Database records updated: $($emailedBarcodes.Count)" -ForegroundColor Green
    Write-Host "❌ Failed to send: $errorCount emails" -ForegroundColor Red
    Write-Host "⚠️  Skipped (no PDF): $skippedCount attendees" -ForegroundColor Yellow
    
    # Write error log and skipped list to files
    if ($errorLog.Count -gt 0) {
        $errorLogPath = Join-Path $OutputFolder "send_errors.txt"
        $errorLog | Out-File -FilePath $errorLogPath -Encoding UTF8
        Write-Host "📄 Error log written to: $errorLogPath" -ForegroundColor Gray
    }
    
    if ($missingPdfs.Count -gt 0) {
        $skippedLogPath = Join-Path $OutputFolder "skipped.txt"
        $missingPdfs | Out-File -FilePath $skippedLogPath -Encoding UTF8
        Write-Host "📄 Skipped list written to: $skippedLogPath" -ForegroundColor Gray
    }
}