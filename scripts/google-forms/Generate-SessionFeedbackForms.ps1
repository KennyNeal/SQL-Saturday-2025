# Generate Google Forms for Session Feedback
# This script creates a Google Form for each session from Sessionize API data
# 
# Prerequisites:
# 1. Google Cloud Project with Forms API enabled
# 2. OAuth 2.0 credentials configured
# 3. PowerShell 7+ with RestMethod support

param(
    [Parameter(Mandatory = $true)]
    [string]$ClientId,
    
    [Parameter(Mandatory = $true)]
    [SecureString]$ClientSecret,
    
    [Parameter(Mandatory = $false)]
    [string]$SessionDataPath = ".\sessions.json",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\output\session-forms.csv"
)

# Configuration
$BaseApiUrl = "https://forms.googleapis.com/v1"
$SessionizeApiUrl = "https://sessionize.com/api/v2/ta7h58rh/view/Sessions"

# Import authentication module
$authModulePath = Join-Path $PSScriptRoot "GoogleFormsAuth.psm1"
Import-Module $authModulePath -Force

# Error handling and logging
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

function Get-GoogleAccessToken {
    <#
    .SYNOPSIS
        Gets Google Forms API access token using OAuth 2.0
    #>
    param(
        [string]$ClientId,
        [SecureString]$ClientSecret
    )
    
    try {
        Write-Log "Authenticating with Google Forms API..."
        
        # Use the secure authentication module
        $accessToken = Get-GoogleFormsAccessToken -ClientId $ClientId -ClientSecret $ClientSecret
        
        Write-Log "Authentication successful"
        return $accessToken
        
    } catch {
        Write-Log "Authentication failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Get-SessionData {
    param(
        [string]$SessionDataPath
    )
    
    try {
        if (Test-Path $SessionDataPath) {
            Write-Log "Loading session data from file: $SessionDataPath"
            $sessionData = Get-Content $SessionDataPath | ConvertFrom-Json
        } else {
            Write-Log "Fetching session data from Sessionize API..."
            $response = Invoke-RestMethod -Uri $SessionizeApiUrl -Method Get
            $sessionData = $response
            
            # Save for future use
            $sessionData | ConvertTo-Json -Depth 10 | Out-File $SessionDataPath -Encoding UTF8
            Write-Log "Session data saved to: $SessionDataPath"
        }
        
        return $sessionData
        
    } catch {
        Write-Log "Failed to get session data: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function New-SessionFeedbackForm {
    param(
        [string]$AccessToken,
        [object]$Session,
        [string]$RoomName
    )
    
    try {
        $sessionTitle = $Session.title
        $speakers = ($Session.speakers | ForEach-Object { $_.name }) -join ", "
        $startTime = [DateTime]::Parse($Session.startsAt).ToString("MM/dd/yyyy HH:mm")
        
        Write-Log "Creating form for session: $sessionTitle"
        
        # Form structure following Google Forms API v1 schema
        $formData = @{
            info = @{
                title = "Session Feedback: $sessionTitle"
                description = @"
Please provide your feedback for this session:

**Session:** $sessionTitle
**Speaker(s):** $speakers
**Room:** $RoomName
**Time:** $startTime

Your feedback helps us improve future events and helps speakers enhance their presentations.
"@
            }
            settings = @{
                quizSettings = @{
                    isQuiz = $false
                }
            }
            responderUri = ""
        }
        
        # Create the form
        $headers = @{
            "Authorization" = "Bearer $AccessToken"
            "Content-Type" = "application/json"
        }
        
        $formResponse = Invoke-RestMethod -Uri "$BaseApiUrl/forms" -Method Post -Headers $headers -Body ($formData | ConvertTo-Json -Depth 10)
        $formId = $formResponse.formId
        
        Write-Log "Form created with ID: $formId"
        
        # Add questions using batchUpdate
        $batchUpdateData = @{
            requests = @(
                # Speaker Knowledge Rating (1-5)
                @{
                    createItem = @{
                        item = @{
                            title = "Speaker Knowledge"
                            description = "How would you rate the speaker's knowledge of the subject matter?"
                            questionItem = @{
                                question = @{
                                    required = $true
                                    scaleQuestion = @{
                                        low = 1
                                        high = 5
                                        lowLabel = "Poor"
                                        highLabel = "Excellent"
                                    }
                                }
                            }
                        }
                        location = @{
                            index = 0
                        }
                    }
                },
                # Presentation Skills Rating (1-5)
                @{
                    createItem = @{
                        item = @{
                            title = "Presentation Skills"
                            description = "How would you rate the speaker's presentation skills?"
                            questionItem = @{
                                question = @{
                                    required = $true
                                    scaleQuestion = @{
                                        low = 1
                                        high = 5
                                        lowLabel = "Poor"
                                        highLabel = "Excellent"
                                    }
                                }
                            }
                        }
                        location = @{
                            index = 1
                        }
                    }
                },
                # Demos Rating (1-5)
                @{
                    createItem = @{
                        item = @{
                            title = "Demos and Examples"
                            description = "How would you rate the quality and relevance of the demos and examples?"
                            questionItem = @{
                                question = @{
                                    required = $true
                                    scaleQuestion = @{
                                        low = 1
                                        high = 5
                                        lowLabel = "Poor"
                                        highLabel = "Excellent"
                                    }
                                }
                            }
                        }
                        location = @{
                            index = 2
                        }
                    }
                },
                # Learning Expectations Rating (1-5)
                @{
                    createItem = @{
                        item = @{
                            title = "Did you learn what you expected?"
                            description = "Did this session meet your learning expectations?"
                            questionItem = @{
                                question = @{
                                    required = $true
                                    scaleQuestion = @{
                                        low = 1
                                        high = 5
                                        lowLabel = "Not at all"
                                        highLabel = "Completely"
                                    }
                                }
                            }
                        }
                        location = @{
                            index = 3
                        }
                    }
                },
                # Improvement Suggestions (Free text)
                @{
                    createItem = @{
                        item = @{
                            title = "What can the speaker do to improve?"
                            description = "Please provide constructive feedback on how the speaker could improve their presentation."
                            questionItem = @{
                                question = @{
                                    required = $false
                                    textQuestion = @{
                                        paragraph = $true
                                    }
                                }
                            }
                        }
                        location = @{
                            index = 4
                        }
                    }
                },
                # Positive Feedback (Free text)
                @{
                    createItem = @{
                        item = @{
                            title = "What did you like about the speaker and session?"
                            description = "Please share what you enjoyed most about this session and the speaker's delivery."
                            questionItem = @{
                                question = @{
                                    required = $false
                                    textQuestion = @{
                                        paragraph = $true
                                    }
                                }
                            }
                        }
                        location = @{
                            index = 5
                        }
                    }
                }
            )
        }
        
        # Add questions to form
        $null = Invoke-RestMethod -Uri "$BaseApiUrl/forms/$formId`:batchUpdate" -Method Post -Headers $headers -Body ($batchUpdateData | ConvertTo-Json -Depth 10)
        
        Write-Log "Questions added to form successfully"
        
        # Set form to published state (required for responses)
        $publishData = @{
            publishingAction = "PUBLISH"
        }
        
        $null = Invoke-RestMethod -Uri "$BaseApiUrl/forms/$formId`:setPublishSettings" -Method Post -Headers $headers -Body ($publishData | ConvertTo-Json -Depth 5)
        
        Write-Log "Form published successfully"
        
        # Return form information
        return @{
            SessionId = $Session.id
            SessionTitle = $sessionTitle
            Speakers = $speakers
            Room = $RoomName
            StartTime = $startTime
            FormId = $formId
            FormUrl = "https://docs.google.com/forms/d/$formId/viewform"
            ResponsesUrl = "https://docs.google.com/forms/d/$formId/responses"
        }
        
    } catch {
        Write-Log "Failed to create form for session '$sessionTitle': $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Export-FormResults {
    param(
        [array]$FormResults,
        [string]$OutputPath
    )
    
    try {
        Write-Log "Exporting results to: $OutputPath"
        
        # Ensure output directory exists
        $outputDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        
        # Convert to CSV
        $FormResults | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        
        Write-Log "Results exported successfully"
        
        # Also create a summary report
        $summaryPath = $OutputPath -replace '\.csv$', '-summary.txt'
        $summary = @"
Session Feedback Forms Generation Summary
Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Total Forms Created: $($FormResults.Count)

Forms by Room:
$($FormResults | Group-Object Room | ForEach-Object { "  $($_.Name): $($_.Count) forms" } | Out-String)

All forms are now available for attendee feedback.
Forms will automatically collect responses and can be accessed via the ResponsesUrl for each session.
"@
        
        $summary | Out-File $summaryPath -Encoding UTF8
        Write-Log "Summary report saved to: $summaryPath"
        
    } catch {
        Write-Log "Failed to export results: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Main execution
try {
    Write-Log "Starting Google Forms generation for SQL Saturday sessions..."
    
    # Get authentication token
    $accessToken = Get-GoogleAccessToken -ClientId $ClientId -ClientSecret $ClientSecret
    
    # Get session data
    $sessionData = Get-SessionData -SessionDataPath $SessionDataPath
    
    # Initialize results collection
    $formResults = @()
    
    # Process each room/track
    foreach ($room in $sessionData) {
        $roomName = $room.groupName
        Write-Log "Processing room: $roomName"
        
        # Skip preconference workshops for now (they may not need feedback forms)
        $regularSessions = $room.sessions | Where-Object { 
            $_.categories | Where-Object { $_.name -eq "Session format" } | 
            ForEach-Object { $_.categoryItems | Where-Object { $_.name -notlike "*Workshop*" } }
        }
        
        foreach ($session in $regularSessions) {
            try {
                # Skip service sessions (breaks, lunch, etc.)
                if ($session.isServiceSession -eq $true) {
                    Write-Log "Skipping service session: $($session.title)"
                    continue
                }
                
                # Create form for this session
                $formResult = New-SessionFeedbackForm -AccessToken $accessToken -Session $session -RoomName $roomName
                $formResults += $formResult
                
                Write-Log "Form created for: $($session.title)"
                
                # Rate limiting - be respectful to Google's API
                Start-Sleep -Milliseconds 500
                
            } catch {
                Write-Log "Error creating form for session '$($session.title)': $($_.Exception.Message)" "ERROR"
                # Continue with other sessions
            }
        }
    }
    
    # Export results
    Export-FormResults -FormResults $formResults -OutputPath $OutputPath
    
    Write-Log "Google Forms generation completed successfully!"
    Write-Log "Created $($formResults.Count) feedback forms"
    Write-Log "Results saved to: $OutputPath"
    
} catch {
    Write-Log "Script execution failed: $($_.Exception.Message)" "ERROR"
    exit 1
}
