<#

.SYNOPSIS
A sample script to query a CSV file for devices and import
those devices into Dashworks.

.DESCRIPTION
A sample script to query a CSV file for devices and import
those devices into Dashworks. Script will either update or create
the device.

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$DwInstance,
    [Parameter(Mandatory=$false)]
    [int]$DwPort = 8443,
    [Parameter(Mandatory=$true)]
    [string]$DwAPIKey,
    [Parameter(Mandatory=$true)]
    [string]$DwFeedName,
    [Parameter(Mandatory=$true)]
    [string]$Path
)

#Requires -Version 7
#Requires -Module @{ ModuleName = 'Juriba.Dashworks'; ModuleVersion = '0.0.14' }

$DashworksParams = @{
    Instance = $DwInstance
    Port = $DwPort
    APIKey = $DwAPIKey
}

# Get DW feed
$feed = Get-DwImportDeviceFeed @DashworksParams -FeedName $DwFeedName
# If it doesnt exist, create it
if (-Not $feed) {
    $feed = New-DwImportDeviceFeed @DashworksParams -Name $DwFeedName -Enabled $true
}
$importId = $feed.id

Write-Information ("Using feed id {0}" -f $importId) -InformationAction Continue

# Run query against MECM database
# Write-Information ("MECM query returned {0} rows." -f $table.count) -InformationAction Continue
$csvFile = Import-Csv -Path $Path 

$origin = @{}
$csvFile | Foreach-Object {$origin.($_.uniqueIdentifier) = @{}}

# Create synced hashtable
$sync = [System.Collections.Hashtable]::Synchronized($origin)

$job = $csvFile | ForEach-Object -ThrottleLimit 16 -Parallel {
    $syncCopy = $using:sync
    $process = $syncCopy.$($_.uniqueIdentifier)

    $process.Id = $_.uniqueIdentifier
    $process.Activity = "Id $($_.uniqueIdentifier) starting"
    $process.Status = "Processing"

    Import-Module .\Juriba.Dashworks\Juriba.Dashworks.psd1
    # convert table row to json, exclude attributes we dont need
    $jsonBody = $_ | ConvertTo-Json
    $uniqueIdentifier = $_.uniqueIdentifier

    $existingDevice = Get-DwImportDevice -Instance $using:DashworksParams.Instance -APIKey $using:DashworksParams.APIKey -ImportId $using:importId -UniqueIdentifier $uniqueIdentifier
    if ($existingDevice) {
        $result = Set-DwImportDevice -Instance $using:DashworksParams.Instance -APIKey $using:DashworksParams.APIKey -ImportId $using:importId -UniqueIdentifier $uniqueIdentifier -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        $result = New-DwImportDevice -Instance $using:DashworksParams.Instance -APIKey $using:DashworksParams.APIKey -ImportId $using:importId -JsonBody $jsonBody
        #check result, for a new device we expect the return object to contain the device
        if ($result -And -Not $result.uniqueIdentifier) {
            Write-Error $result
        }
        elseif (-not $result) {
            Write-Error 
        }

    }
    # Mark process as completed
    $process.Completed = $true
}


while($job.State -eq 'Running')
{
    $sync.Keys | Foreach-Object {
        # If key is not defined, ignore
        if(![string]::IsNullOrEmpty($sync.$_.keys))
        {
            # Create parameter hashtable to splat
            $param = $sync.$_

            # Execute Write-Progress
            Write-Progress @param
        }
    }

    # Wait to refresh to not overload gui
    Start-Sleep -Seconds 0.25
}

