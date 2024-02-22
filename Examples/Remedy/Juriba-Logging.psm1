# Get the directory of the currently executing scriptDefinition
$scriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Define the log directory as a subdirectory named 'Logs' within the script directory
$logDirectory = Join-Path -Path $scriptDirectory -ChildPath "Logs"

# Check if the log directory exists, if not create it
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory -Force
}

# Define log file prefixes
$DEV_logPrefix = "Lab_"
$UAT_logPrefix = "UAT_"
$PROD_logPrefix = "PROD_"

# Determine the current environment:
$environment = "DEV" # "UAT" # or "PROD" 

# Determine how many days worth of log files you want to maintain older files are deleted. 
$daysToKeepLogs = 3

# Select the appropriate log file path based on the environment
$logFilePath = switch ($environment) {
    "DEV" { Join-Path -Path $logDirectory -ChildPath "$DEV_logPrefix$(get-date -format yyyyMMdd)_$(Get-Date -format 'HHmm').log" }
    "UAT" { Join-Path -Path $logDirectory -ChildPath "$UAT_logPrefix$(get-date -format yyyyMMdd)_$(Get-Date -format 'HHmm').log" }
    "PROD" { Join-Path -Path $logDirectory -ChildPath "$PROD_logPrefix$(get-date -format yyyyMMdd)_$(Get-Date -format 'HHmm').log" }
}

# Append a log entry to the log file and optionally write to the console
function Add-LogEntry {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Entry,
        
        [Parameter(Mandatory = $false)]
        [bool]$WriteToConsole = $true, # Switch parameter for console output
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Noise', 'Debug', 'Info', 'Warning', 'Error', 'Fatal')]
        [string]$JuribaLogLevel = 'Info',

        [Parameter(Mandatory = $false)]
        [bool]$SendToJuriba = $true
        
    )

    # Check the log file exists, if not create it
    if (-not (Test-Path -Path $logFilePath)) {
        New-Item -Path $logFilePath -ItemType File -Force
    }
    
    $timestampedEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Entry"
    
    # Write entry to log file
    $timestampedEntry | Out-File -Append -FilePath $logFilePath -Force -Width 4000

    # If $WriteToConsole is specified, also write the entry to the console
    if ($WriteToConsole) {
        Write-Host $timestampedEntry
    }
    # If JuribaLogLevel is specified, call Add-JuribaLogMessage
    if ($SendToJuriba) {
        Add-JuribaLogMessage -Instance $JuribaParams.Instance -APIKey $JuribaParams.APIKey -Priority $JuribaLogLevel -Message $Entry
    }
}

# Delete log files older than the specified number of days
function Remove-OldLogFiles {
    param (
        [Parameter(Mandatory=$true)]
        [string]$LogDirectory,
        [Parameter(Mandatory=$false)]
        [byte]$WriteToConsole = 0,
        [Parameter(Mandatory=$true)]
        [int]$DaysToKeepLogs
    )

    # Determine log prefix based on the environment
    $logPrefix = switch ($environment) {
        "DEV" { $DEV_logPrefix }
        "UAT" { $UAT_logPrefix }
        "PROD" { $PROD_logPrefix }
        default { throw "Invalid environment specified." }
    }

    $logFiles = Get-ChildItem -Path $LogDirectory -Filter "$logPrefix*" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$DaysToKeepLogs) }

    if ($logFiles.Count -gt 0) {
        foreach ($logFile in $logFiles) {
            Add-LogEntry -Entry "Deleting $($logFile.Name)..." -WriteToConsole $WriteToConsole
            Remove-Item -Path $logFile.FullName -Force
        }
        Add-LogEntry -Entry "Deleted $($logFiles.Count) old log file(s)." -WriteToConsole $WriteToConsole
    } else {
        Add-LogEntry -Entry "No old log files found." -WriteToConsole $WriteToConsole
    }
}

function Start-JuribaLog {
    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,
 
        [Parameter(Mandatory=$True)]
        [string]$APIKey
    )
    $Headers = @{"accept" = "application/json";"X-API-KEY" = $APIKey;"Content-Type"="application/json"}
    Invoke-webrequest -uri "$($Instance)/apiv2/event-logs/start-event-logging-command" -Method Post -Headers $Headers -Body "{""ServiceId"": 19}" -AllowInsecureRedirect | Out-Null
}
function Add-JuribaLogMessage {
    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,
        [Parameter(Mandatory=$True)]
        [string]$APIKey,
        [parameter(Mandatory=$True)]
        [ValidateSet('Noise','Debug','Info','Warning','Error','Fatal')]
        [string]$Priority,
        [Parameter(Mandatory=$True)]
        [string]$Message
    )
    $Headers = @{"accept" = "application/json";"X-API-KEY" = $APIKey;"Content-Type"="application/json"}
    $body = @{"message"=$Message;"source"="Import Script";"level"=$Priority} | ConvertTo-Json
    Invoke-webrequest -uri "$($Instance)/apiv2/event-logs" -Method Post -Headers $Headers -Body $Body -AllowInsecureRedirect | Out-Null
}
function Close-JuribaLog {
    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,
 
        [Parameter(Mandatory=$True)]
        [string]$APIKey
    )
    $Headers = @{"accept" = "application/json";"X-API-KEY" = $APIKey;"Content-Type"="application/json"}
    Invoke-webrequest -uri "$($Instance)/apiv2/event-logs/stop-event-logging-command" -Method Post -Headers $Headers -AllowInsecureRedirect | Out-Null
}
function Initialize-JuribaLogging {
    # Call Remove-OldLogFiles with the correct parameters
    Remove-OldLogFiles -LogDirectory $logDirectory -DaysToKeepLogs $daysToKeepLogs -WriteToConsole $WriteToConsole
}

# Export the functions you want to make available outside the module
Export-ModuleMember -Function Add-LogEntry, Remove-OldLogFiles, Start-JuribaLog, Close-JuribaLog

# Call Initialize-JuribaLogging to execute its logic automatically upon import
Initialize-JuribaLogging



