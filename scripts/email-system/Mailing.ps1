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
Path to folder containing PDF files. Defaults to output\speedpasses in project root.

.PARAMETER CredPath
Path to encrypted Gmail credentials file. Defaults to config\gmail-cred.xml in project root.

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
    [string]$OutputFolder,
    [string]$CredPath,
    [int]$DelaySeconds = 2,
    [int]$BatchSize = 50,
    [ValidateSet("attendee", "volunteer")][string]$EmailType = "attendee",
    [string]$TestEmail = ""
)

# Use script location to find project root and set default paths
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)
$templateFolder = Join-Path $scriptPath "templates"
if (-not $OutputFolder) { $OutputFolder = Join-Path $projectRoot "output\speedpasses" }
if (-not $CredPath) { $CredPath = Join-Path $projectRoot "config\gmail-cred.xml" }

# Load email templates
function Get-EmailTemplate {
    param(
        [string]$TemplateName,
        [string]$TemplateFolder
    )
    
    $templatePath = Join-Path $TemplateFolder "$TemplateName.html"
    if (Test-Path $templatePath) {
        return Get-Content -Path $templatePath -Raw
    } else {
        throw "Template file not found: $templatePath"
    }
}

# CONFIGURATION
$markEmailedProc = "dbo.AttendeesMarkAsEmailed"
$markBatchEmailedProc = "dbo.AttendeesMarkBatchAsEmailed"

# Load email templates
$bannerTemplate = Get-EmailTemplate -TemplateName "banner" -TemplateFolder $templateFolder
$attendeeTemplate = Get-EmailTemplate -TemplateName "attendee-email" -TemplateFolder $templateFolder
$volunteerTemplate = Get-EmailTemplate -TemplateName "volunteer-email" -TemplateFolder $templateFolder

switch ($EmailType) {
    "attendee" {
        $getAttendeesQuery = "EXEC dbo.AttendeesGetForEmail"
        $subject = "See You at SQL Saturday Baton Rouge 2025!"
        $bodyTemplate = $attendeeTemplate
    }
    "volunteer" {
        $getAttendeesQuery = @"
SELECT DISTINCT First_Name, Last_Name, Email
FROM SQLSaturday..Attendees
WHERE Are_you_willing_to_volunteer_during_the_event = 'Yes'
"@
        $subject = "Volunteer for SQL Saturday Baton Rouge 2025!"
        $bodyTemplate = $volunteerTemplate
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

Write-Host "SQL Saturday Email Sender"
if ($WhatIfPreference) {
    Write-Host "WHATIF MODE: No emails will be sent, no database changes will be made"
}
Write-Host "Output Folder: $OutputFolder"
Write-Host "From: $from"
Write-Host "Banner Enabled: $ShowBanner"
Write-Host "Email Type: $EmailType"

# FETCH ATTENDEE EMAILS
Write-Host "`nFetching attendees from database..."

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
    Write-Host "Found $($attendees.Count) attendees to process"
    if ($attendees.Count -eq 0) {
        Write-Host "No attendees found. Exiting."
        return
    }
} catch {
    Write-Error "Database error: $_"
    return
}

# After fetching attendees, filter for test mode
if ($TestEmail -and $TestEmail -ne "") {
    $attendees = $attendees | Where-Object { $_.Email -eq $TestEmail }
    Write-Host "TEST MODE: Only sending to $TestEmail"
}

# Validate PDF files and create processing summary
$validAttendees = @()
$missingPdfs = @()

Write-Host "`nValidating PDF files..."

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

Write-Host "Valid PDFs found: $($validAttendees.Count)"
if ($missingPdfs.Count -gt 0) {
    Write-Host "Missing PDFs: $($missingPdfs.Count)"
}

if ($WhatIfPreference) {
    Write-Host "`nPREVIEW - Emails that would be sent:"
    $validAttendees | ForEach-Object { 
        Write-Host "  $($_.Attendee.Email) <- $($_.SafeName).pdf"
    }
    
    if ($missingPdfs.Count -gt 0) {
        Write-Host "`nPREVIEW - Attendees that would be skipped (missing PDFs):"
        $missingPdfs | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
    
    Write-Host "`nSUMMARY:"
    Write-Host "  Emails to send: $($validAttendees.Count)"
    Write-Host "  Skipped (no PDF): $($missingPdfs.Count)"
    Write-Host "  Output folder: $OutputFolder"
    Write-Host "`nTo actually send emails, run without -WhatIf parameter"
    return
}

# SEND EMAILS
if ($validAttendees.Count -gt 0) {
    Write-Host "`nStarting email send process..."
    Write-Host "Processing in batches of $BatchSize"
    
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
            Write-Host "  Database logging failed for $Barcode : $_"
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
                Write-Host "  Batch update: $message"
            }
            $batchConn.Close()
        } catch {
            Write-Host "  Batch database logging failed: $_"
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
        
        Write-Host "`nProcessing batch $batchNumber of $totalBatches ($($batch.Count) emails)..."
        
        foreach ($item in $batch) {
            $a = $item.Attendee
            
            # Process template placeholders
            $body = $bodyTemplate
            $body = $body -replace '{{FirstName}}', $a.FirstName
            $body = $body -replace '{{BANNER}}', $(if ($ShowBanner) { $bannerTemplate } else { "" })
            
            try {
                if ($EmailType -eq "attendee") {
                    $subject = "See You at SQL Saturday Baton Rouge 2025!"
                    
                    Send-MailMessage -To $a.Email -From $from -Subject $subject -Body $body `
                        -SmtpServer $smtp -Port $port -UseSsl -Credential $cred -Attachments $item.PdfPath -BodyAsHtml -WarningAction SilentlyContinue
                } elseif ($EmailType -eq "volunteer") {
                    $subject = "Volunteer for SQL Saturday Baton Rouge 2025!"
                    
                    Send-MailMessage -To $a.Email -From $from -Subject $subject -Body $body `
                        -SmtpServer $smtp -Port $port -UseSsl -Credential $cred -BodyAsHtml -WarningAction SilentlyContinue
                }
                
                Write-Host "Sent: $($item.SafeName).pdf -> $($a.Email)"
                
                # Add to batch for database logging
                $batchEmailedBarcodes += $a.Barcode
                $emailedBarcodes += $a.Barcode
                $successCount++
                
            } catch {
                $errorMessage = "Error sending to $($a.Email): $_"
                Write-Host "ERROR: $errorMessage" -ForegroundColor Red
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
            Write-Host "Waiting before next batch..."
            Start-Sleep -Seconds ($DelaySeconds * 2)
        }
    }
    
    # Final summary
    Write-Host "`nFINAL SUMMARY:"
    Write-Host "Successfully sent: $successCount emails"
    Write-Host "Database records updated: $($emailedBarcodes.Count)"
    Write-Host "Failed to send: $errorCount emails" -ForegroundColor Red
    Write-Host "Skipped (no PDF): $skippedCount attendees"
    
    # Write error log and skipped list to files
    if ($errorLog.Count -gt 0) {
        $errorLogPath = Join-Path $OutputFolder "send_errors.txt"
        $errorLog | Out-File -FilePath $errorLogPath -Encoding UTF8
        Write-Host "Error log written to: $errorLogPath"
    }
    
    if ($missingPdfs.Count -gt 0) {
        $skippedLogPath = Join-Path $OutputFolder "skipped.txt"
        $missingPdfs | Out-File -FilePath $skippedLogPath -Encoding UTF8
        Write-Host "Skipped list written to: $skippedLogPath"
    }
}