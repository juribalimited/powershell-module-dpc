# Get the directory of the currently executing scriptDefinition
$scriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Define the log directory as a subdirectory named 'Logs' within the script directory
$Script:logDirectory = Join-Path -Path $scriptDirectory -ChildPath "Logs"
$Script:scriptName = (Get-Item $Script:MyInvocation.ScriptName).BaseName

# Determine how many days worth of log files you want to maintain older files are deleted.
$daysToKeepLogs = 3

# Append a log entry to the log file and optionally write to the console
function Add-LogEntry { 
    <#
	.SYNOPSIS
	Write to a log file.
	.DESCRIPTION
	Creates a new log file or appends to an existing log file.
	.PARAMETER Entry
	String to write to the log.
	.PARAMETER LogLevel
	'Noise', 'Debug', (Default)'Info', 'Warning', 'Error', 'Fatal'
	.PARAMETER Path
	Log file to write to. Defaults to $logDirectory.
	.PARAMETER Component
	String for the "Component" column.
	.PARAMETER WriteToConsole
	Also write to the console.
    .PARAMETER Environment
	Defines the environment for naming log files. 'DEV', 'UAT', 'PROD'
    .PARAMETER SendtoJuriba
	Sends log entry to Juriba if. Default is True.
    .EXAMPLE
	Add-LogEntry -Entry "Gathering data from Source" -SendtoJuriba $false
    .EXAMPLE
	Add-LogEntry -Entry "Gathering data from Source" -LogLevel Error -Path "C:\ustom\Path" -Component "ActionSummary" -WriteToConsole $false 
    -Environment Prod -SendtoJuriba $false
	#>
    param (
        [Parameter(Mandatory = $true,Position=0)]
        [string]$Entry,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Noise', 'Debug', 'Info', 'Warning', 'Error', 'Fatal')]
        [string]$LogLevel = 'Info',

        [Parameter(Mandatory = $false)]
        [string]$path = $Script:logDirectory,
        
        [Parameter(Mandatory = $false)]
        [string]$Component = $Script:scriptName, # Component can be used in Trace32 log format for easier filtering
        
        [Parameter(Mandatory = $false)]
        [bool]$WriteToConsole = $true, # Switch parameter for console output

        [Parameter(Mandatory = $false)]
        [ValidateSet('DEV', 'UAT', 'PROD')]
        [string]$Environment = 'DEV',
        
        [Parameter(Mandatory = $false)]
        [bool]$SendToJuriba = $true
    )

    # Set Severity for use with CMTrace/Trace32 format logs
    $Severity = Switch ($LogLevel){
        'Noise' { 1 }
        'Info'  { 1 }
        'Error' { 3 }
        'Fatal' { 3 }
        'Debug' { 2 }
        'Warning' { 2 }
    }

    # Define log file prefixes
    $DEV_logPrefix = "Lab_"
    $UAT_logPrefix = "UAT_"
    $PROD_logPrefix = "PROD_"

    # Select the appropriate log file path based on the environment
    $logFilePath = switch ($environment) {
        "DEV" { Join-Path -Path $logDirectory -ChildPath "$DEV_logPrefix$(get-date -format yyyyMMdd)_$(Get-Date -format 'HHmm').log" }
        "UAT" { Join-Path -Path $logDirectory -ChildPath "$UAT_logPrefix$(get-date -format yyyyMMdd)_$(Get-Date -format 'HHmm').log" }
        "PROD" { Join-Path -Path $logDirectory -ChildPath "$PROD_logPrefix$(get-date -format yyyyMMdd)_$(Get-Date -format 'HHmm').log" }
    }

    # Check if the log directory exists, if not create it
    Try {
        if (-not (Test-Path -Path $logDirectory)) {
            If ($WriteToConsole){ Write-Host "Creating Log Directory: $logDirectory" }
            New-Item -Path $logDirectory -ItemType Directory -Force -ErrorAction Stop > $null
        }    
    } Catch {
        Write-Error "Failed to create log directory - $logDirectory : $_"
    }
    
    # Check the log file exists, if not create it
    Try {
        if (-not (Test-Path -Path $logFilePath)) {
            If ($WriteToConsole){ Write-Host "Creating Log File: $logDirectory" }
            New-Item -Path $logFilePath -ItemType File -Force -ErrorAction Stop > $null
        }    
    } Catch {
        Write-Error "Failed to create log file - $logFilePath : $_"
    }
    
    <# Placeholder code if CMTrace/Trace32 format is preferred
	$TimeZoneBias = [math]::Abs(([System.TimeZoneInfo]::Local).BaseUtcOffset.TotalMinutes) - $(If ((Get-Date).IsDayLightSavingTime()) { 60 } Else { 0 })
	$Date = Get-Date -Format "HH:mm:ss.fff"
	$Date2 = Get-Date -Format "MM-dd-yyyy"
	"<![LOG[$Entry]LOG]!><time=`"$date+$TimeZoneBias`" date=`"$date2`" component=`"$component`" context=`"`" type=`"$severity`" thread=`"`" file=`"`">" | Out-File -FilePath $logFilePath -Append -NoClobber -Encoding default -Force -Width 4000
    #>

    $timestampedEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Entry"
    
    # Write entry to log file
    $timestampedEntry | Out-File -Append -FilePath $logFilePath -Force -Width 4000

    # If $WriteToConsole is specified, also write the entry to the console
    if ($WriteToConsole) {
        Switch ($LogLevel){ # Use LogLevel param to format console output
            'Noise' { Write-Host $timestampedEntry }
            'Info'  { Write-Host $timestampedEntry }
            'Error' { Write-Error $timestampedEntry }
            'Fatal' { Write-Error $timestampedEntry }
            'Debug' { Write-Verbose $timestampedEntry -Verbose }
            'Warning' { Write-Warning $timestampedEntry }
        }
    }

    # If SendToJuriba is specified, call Add-JuribaLogMessage
    if ($SendToJuriba) {
        #TODO: Confirm $JuribaParams object is accessible within context of this function without passing in explicitly.
        # Adding Script: to set variable scope to hopefully retrieve the JuribaParams object successfully.
        Add-JuribaLogMessage -Instance $Script:JuribaParams.Instance -APIKey $Script:JuribaParams.APIKey -Priority $LogLevel -Message $Entry
    }
}

# Delete log files older than the specified number of days
function Remove-OldLogFiles {
    param (
        [Parameter(Mandatory=$true)]
        [string]$LogDirectory,
        [Parameter(Mandatory = $false)]
        [ValidateSet('DEV', 'UAT', 'PROD')]
        [string]$Environment = 'DEV',
        [Parameter(Mandatory=$false)]
        [byte]$WriteToConsole = 0,
        [Parameter(Mandatory=$true)]
        [int]$DaysToKeepLogs
    )

    # Define log file prefixes
    $DEV_logPrefix = "Lab_"
    $UAT_logPrefix = "UAT_"
    $PROD_logPrefix = "PROD_"

    # Determine log prefix based on the environment
    $logPrefix = switch ($environment) {
        "DEV" { $DEV_logPrefix }
        "UAT" { $UAT_logPrefix }
        "PROD" { $PROD_logPrefix }
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
    #TODO: Understand why we are using Remove-OldLogFiles inside of another function name rather than just calling the function in a script or from within Add-LogEntry
    Remove-OldLogFiles -LogDirectory $logDirectory -DaysToKeepLogs $daysToKeepLogs -WriteToConsole $WriteToConsole
}

# Export the functions you want to make available outside the module
Export-ModuleMember -Function Add-LogEntry, Remove-OldLogFiles, Start-JuribaLog, Close-JuribaLog

# Call Initialize-JuribaLogging to execute its logic automatically upon import
Initialize-JuribaLogging