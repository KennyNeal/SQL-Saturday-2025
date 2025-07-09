# CONFIGURATION
$connectionString = "Server=localhost\SQLEXPRESS;Database=SQLSaturday;Integrated Security=SSPI;"
$query = "SELECT First_Name, Last_Name, Email FROM dbo.AttendeesGetUnPrintedOrdersBase"
$outputFolder = "C:\Users\kneal\OneDrive\Documents\SQL Saturday 2025\SpeedPass"
$credPath     = "C:\Users\kneal\gmail-cred.xml"
$cred         = Import-Clixml -Path $credPath
$from         = $cred.UserName
$smtp         = "smtp.gmail.com"
$port         = 587

# FETCH ATTENDEE EMAILS
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
    }
}
$connection.Close()

# SEND EMAILS
foreach ($a in $attendees) {
    $nameLastFirst = "$($a.LastName), $($a.FirstName)"
    $safeName = $nameLastFirst -replace '\s', '_' -replace '[^\w]', ''
    $pdfPath = Join-Path $outputFolder "$safeName.pdf"

    if (Test-Path $pdfPath) {
        $subject = "Your SQL Saturday SpeedPass"
        $body = @"
Hi $($a.FirstName),

Attached is your personalized speed pass for SQL Saturday 2025.

Please print it or bring it digitally to the event—we’ll scan your badge at check-in and your raffle tickets will be ready to roll!

See you soon!
"@
        Send-MailMessage -To $a.Email -From $from -Subject $subject -Body $body `
            -SmtpServer $smtp -Port $port -UseSsl -Credential $cred -Attachments $pdfPath
        Write-Host "✅ Sent: $safeName.pdf ➝ $($a.Email)"
    } else {
        Write-Host "⚠️ Skipped: No PDF found for $nameLastFirst"
    }
}