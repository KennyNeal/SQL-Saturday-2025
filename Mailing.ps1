# CONFIGURATION
$connectionString = "Server=localhost\SQLEXPRESS;Database=SQLSaturday;Integrated Security=SSPI;"
$query = "SELECT Barcode, First_Name, Last_Name, Email FROM dbo.AttendeesGetUnPrintedOrders"
$outputFolder = "C:\Users\kneal\OneDrive\Documents\SQL Saturday 2025\SpeedPass"
$credPath = "C:\Users\kneal\gmail-cred.xml"
$cred = Import-Clixml -Path $credPath
$from = $cred.UserName
$smtp = "smtp.gmail.com"
$port = 587

# FETCH ATTENDEE EMAILS
$connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
$command = $connection.CreateCommand()
$command.CommandText = $query
$connection.Open()
$reader = $command.ExecuteReader()
$attendees = @()
while ($reader.Read()) {
    $attendees += [PSCustomObject]@{
        Barcode   = $reader["Barcode"]
        FirstName = $reader["First_Name"]
        LastName  = $reader["Last_Name"]
        Email     = $reader["Email"]
    }
}
$connection.Close()

# SEND EMAILS
foreach ($a in $attendees) {
    $nameLastFirst = "$($a.LastName), $($a.FirstName)"
    $safeName = $nameLastFirst -replace '\s', '_' -replace '[^\w]', ''
    $pdfPath = Join-Path $outputFolder "$safeName.pdf"

    if (Test-Path $pdfPath) {
        $subject = "See You at SQL Saturday Baton Rouge 2025!"
        $body = @"
<p style='color: red; font-weight: bold;'>There was an issue with our first batch of emails. We're sorry if you have received this twice.</p>

<p>Hi $($a.FirstName),</p>

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
        try {
            Send-MailMessage -To $a.Email -From $from -Subject $subject -Body $body `
                -SmtpServer $smtp -Port $port -UseSsl -Credential $cred -Attachments $pdfPath -BodyAsHtml -WarningAction SilentlyContinue
            Write-Host "✅ Sent: $safeName.pdf ➝ $($a.Email)"
            # Log successful send to AttendeesPrinted table using Barcode
            $insertConn = New-Object System.Data.SqlClient.SqlConnection $connectionString
            $insertCmd = $insertConn.CreateCommand()
            $insertCmd.CommandText = "INSERT INTO dbo.AttendeesPrinted (Barcode) VALUES (@Barcode)"
            $insertCmd.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@Barcode", $a.Barcode))) | Out-Null
            $insertConn.Open()
            $insertCmd.ExecuteNonQuery() | Out-Null
            Write-Host "✅ Logged print for $($a.Barcode)"
            $insertConn.Close()
            Start-Sleep -Seconds 2
        } catch {
            Write-Host "❌ Error sending to $($a.Email): $_"
            Add-Content -Path "$outputFolder\send_errors.txt" -Value "$($a.Email): $_"
        }
    }
    else {
        Write-Host "⚠️ Skipped: No PDF found for $nameLastFirst"
        Add-Content -Path "$outputFolder\skipped.txt" -Value $nameLastFirst
    }
}