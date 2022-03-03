<#

.SYNOPSIS
A sample script to query a CSV file for devices and import
those devices into Dashworks.

.DESCRIPTION
A sample script to query a CSV file for devices and import
those devices into Dashworks. Script assumes that the CSV file
columns match the json schema for the devices. Script will
either update or create the device.

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$DwInstance,
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
    APIKey = $DwAPIKey
}

# Get DW feed
$feed = Get-DwImportDeviceFeed @DashworksParams -Name $DwFeedName
# If it doesnt exist, create it
if (-Not $feed) {
    $feed = New-DwImportDeviceFeed @DashworksParams -Name $DwFeedName -Enabled $true
}
$importId = $feed.id

Write-Information ("Using feed id {0}" -f $importId) -InformationAction Continue

# read data fom CSV file
$csvFile = Import-Csv -Path $Path

# build hashtable for job
$origin = @{}
$csvFile | Foreach-Object {$origin.($_.uniqueIdentifier) = 0}

# create synced hashtable
$sync = [System.Collections.Hashtable]::Synchronized($origin)

$job = $csvFile | ForEach-Object -AsJob -ThrottleLimit 16 -Parallel {
    $syncCopy = $using:sync

    Import-Module .\Juriba.Dashworks\Juriba.Dashworks.psd1
    # convert table row to json, exclude attributes we dont need
    $jsonBody = $_ | ConvertTo-Json
    $uniqueIdentifier = $_.uniqueIdentifier

    $existingDevice = Get-DwImportDevice @using:DashworksParams -ImportId $using:importId -UniqueIdentifier $uniqueIdentifier
    if ($existingDevice) {
        $result = Set-DwImportDevice @using:DashworksParams -ImportId $using:importId -UniqueIdentifier $uniqueIdentifier -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        $result = New-DwImportDevice @using:DashworksParams -ImportId $using:importId -JsonBody $jsonBody
        # check result, for a new device we expect the return object to contain the device
        if ($result -And -Not $result.uniqueIdentifier) {
            Write-Error $result
        }
    }
    # Mark process as completed
    $syncCopy[$_.uniqueIdentifier] = 1
}


while($job.State -eq 'Running')
{
    $pctComplete = (($sync.GetEnumerator().Where({$_.Value -eq 1}).Count) / $sync.Count) * 100
    Write-Progress -Activity "Importing Devices to Dashworks" -PercentComplete $pctComplete

    # Wait to refresh to not overload gui
    Start-Sleep -Seconds 0.25
}

