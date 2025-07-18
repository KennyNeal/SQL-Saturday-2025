# -requires -module Microsoft.PowerShell.SecretManagement
# -requires -module Microsoft.PowerShell.SecretStore


# CONFIGURATION
#Get Eventbrite API token from https://www.eventbrite.com/platform/api-keys
# Store it securely using Secret Management module

$token = Get-Secret -Name EventbriteToken | ConvertFrom-SecureString -AsPlainText
$header = @{ Authorization = "Bearer $token" }
$eventId = "1228684160399" # Replace with your actual Eventbrite event ID from web (easy) or API.

$connectionString = "Server=localhost\SQLEXPRESS;Database=SQLSaturday;Integrated Security=SSPI;"

# Fetch attendees from Eventbrite
$attendeesUrl = "https://www.eventbriteapi.com/v3/events/$eventId/attendees/"

$attendees = @()
$query = "?status=attending"

Write-Host "Fetching attendees from Eventbrite..."
do {
    $response = Invoke-RestMethod -Method Get -Uri ($attendeesUrl + $query) -Headers $header
    $attendees += $response.attendees
    if ($response.pagination.has_more_items) {
        $query = "?continuation=" + ($response.pagination.continuation)
    } 
} while ($response.pagination.has_more_items)


# Helper: Extract answer by question text
function Get-Answer($answers, $questionText) {
    ($answers | Where-Object { $_.question -like "*$questionText*" }).answer
}

# Connect to SQL and truncate table
$connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
$connection.Open()
$truncateCmd = $connection.CreateCommand()
$truncateCmd.CommandText = "TRUNCATE TABLE dbo.Attendees"
$truncateCmd.ExecuteNonQuery() | Out-Null

# Insert each attendee using stored procedure
foreach ($a in $attendees) {
    $attendeeprofile = $a.profile
    $answers = $a.answers
    $barcode = $null
    if ($a.barcodes) {
        $barcode = ($a.barcodes | Select-Object -First 1).barcode
    }

    $cmd = $connection.CreateCommand()
    $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
    $cmd.CommandText = "dbo.AttendeesInsert"

    $cmd.Parameters.AddWithValue("@Order", $a.order_id) | Out-Null
    $cmd.Parameters.AddWithValue("@Order_Date", $a.created) | Out-Null
    $cmd.Parameters.AddWithValue("@Prefix", $attendeeprofile.prefix) | Out-Null
    $cmd.Parameters.AddWithValue("@First_Name", $attendeeprofile.first_name) | Out-Null
    $cmd.Parameters.AddWithValue("@Last_Name", $attendeeprofile.last_name) | Out-Null
    $cmd.Parameters.AddWithValue("@Email", $attendeeprofile.email) | Out-Null
    $cmd.Parameters.AddWithValue("@Quantity", $a.quantity) | Out-Null
    $cmd.Parameters.AddWithValue("@Ticket_Type", $a.ticket_class_name) | Out-Null
    $cmd.Parameters.AddWithValue("@Attendee", $attendeeprofile.name) | Out-Null
    $cmd.Parameters.AddWithValue("@Barcode", $barcode) | Out-Null
    $cmd.Parameters.AddWithValue("@Order_Type", $null) | Out-Null
    $cmd.Parameters.AddWithValue("@Attendee_Status", $a.status) | Out-Null
    $cmd.Parameters.AddWithValue("@Home_Address_1", $null) | Out-Null
    $cmd.Parameters.AddWithValue("@Home_Address_2", $null) | Out-Null
    $cmd.Parameters.AddWithValue("@Home_City", $null) | Out-Null
    $cmd.Parameters.AddWithValue("@Home_State", $null) | Out-Null
    $cmd.Parameters.AddWithValue("@Home_Zip", $null) | Out-Null
    $cmd.Parameters.AddWithValue("@Home_Country", $null) | Out-Null
    $cmd.Parameters.AddWithValue("@Cell_Phone", $null) | Out-Null
    $cmd.Parameters.AddWithValue("@Accept_Code_of_Conduct", (Get-Answer $answers "Code of Conduct")) | Out-Null
    $cmd.Parameters.AddWithValue("@Lunch_Type", (Get-Answer $answers "Lunch Type")) | Out-Null
    $cmd.Parameters.AddWithValue("@Are_you_willing_to_volunteer_during_the_event", (Get-Answer $answers "volunteer")) | Out-Null
    $cmd.Parameters.AddWithValue("@Twitter_X_UserName", (Get-Answer $answers "Twitter")) | Out-Null
    $cmd.Parameters.AddWithValue("@LinkedIn_URL", $null) | Out-Null
    $cmd.Parameters.AddWithValue("@Job_Title", $attendeeprofile.job_title) | Out-Null
    $cmd.Parameters.AddWithValue("@Company", $attendeeprofile.company) | Out-Null
    $cmd.Parameters.AddWithValue("@Work_Phone", $null) | Out-Null
    $cmd.Parameters.AddWithValue("@Website", $attendeeprofile.website) | Out-Null
    $cmd.Parameters.AddWithValue("@Blog", $null) | Out-Null

    $cmd.ExecuteNonQuery() | Out-Null
}

$connection.Close()
Write-Host "Attendees table reloaded from Eventbrite. Count: $($attendees.Count)"