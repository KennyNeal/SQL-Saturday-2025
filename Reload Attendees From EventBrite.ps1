# CONFIGURATION
#Get Eventbrite API token from https://www.eventbrite.com/platform/api-keys
$token = Get-Secret -Name EventbriteToken
$header = @{ Authorization = "Bearer $token" }
$eventId = "1228684160399" # Replace with your actual Eventbrite event ID from web (easy) or API.

$connectionString = "Server=localhost\SQLEXPRESS;Database=SQLSaturday;Integrated Security=SSPI;"

# Fetch attendees from Eventbrite
$attendeesUrl = "https://www.eventbriteapi.com/v3/events/$eventId/attendees/"

$attendees = @()
$query = "?status=attending"

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

# Insert each attendee
foreach ($a in $attendees) {
    $profile = $a.profile
    $answers = $a.answers

    # Map fields
    $fields = @{
        "Order"                                         = $a.order_id
        "Order_Date"                                    = $a.created
        "Prefix"                                        = $profile.prefix
        "First_Name"                                    = $profile.first_name
        "Last_Name"                                     = $profile.last_name
        "Email"                                         = $profile.email
        "Quantity"                                      = $a.quantity
        "Ticket_Type"                                   = $a.ticket_class_name
        "Attendee"                                      = $profile.name
        "Barcode"                                       = if ($a.barcodes) { ($a.barcodes | Select-Object -First 1).barcode } else { $null }
        "Order_Type"                                    = $null
        "Attendee_Status"                               = $a.status
        "Home_Address_1"                                = $null
        "Home_Address_2"                                = $null
        "Home_City"                                     = $null
        "Home_State"                                    = $null
        "Home_Zip"                                      = $null
        "Home_Country"                                  = $null
        "Cell_Phone"                                    = $null
        "Accept_Code_of_Conduct"                        = Get-Answer $answers "Code of Conduct"
        "Lunch_Type"                                    = Get-Answer $answers "Lunch Type"
        "Are_you_willing_to_volunteer_during_the_event" = Get-Answer $answers "volunteer"
        "Twitter_X_UserName"                            = Get-Answer $answers "Twitter"
        "LinkedIn_URL"                                  = $null
        "Job_Title"                                     = $profile.job_title
        "Company"                                       = $profile.company
        "Work_Phone"                                    = $null
        "Website"                                       = $profile.website
        "Blog"                                          = $null
    }

    # Filter out nulls
    $nonNullFields = $fields.GetEnumerator() | Where-Object { $_.Value -ne $null }
    $columns = ($nonNullFields | ForEach-Object { "[$($_.Key)]" }) -join ", "
    $params = ($nonNullFields | ForEach-Object { "@$($_.Key)" }) -join ", "

    $cmd = $connection.CreateCommand()
    $cmd.CommandText = "INSERT INTO dbo.Attendees ($columns) VALUES ($params)"

    foreach ($item in $nonNullFields) {
        $cmd.Parameters.AddWithValue("@$($item.Key)", $item.Value) | Out-Null
    }

    $cmd.ExecuteNonQuery() | Out-Null
}


$connection.Close()
Write-Host "Attendees table reloaded from Eventbrite."