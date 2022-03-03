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

# Get data from CSV file
$csvFile = Import-Csv -Path $Path

$i = 0
foreach ($line in $csvFile) {
    $i++
    # convert line to json
    $jsonBody = $line | ConvertTo-Json
    $uniqueIdentifier = $line.uniqueIdentifier
    Write-Progress -Activity "Importing Devices to Dashworks" -Status ("Processing device: {0}" -f $uniqueIdentifier) -PercentComplete (($i/$csvFile.Count*100))

    $existingDevice = Get-DwImportDevice @DashworksParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier
    if ($existingDevice) {
        $result = Set-DwImportDevice @DashworksParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        $result = New-DwImportDevice @DashworksParams -ImportId $importId -JsonBody $jsonBody
        #check result, for a new device we expect the return object to contain the device
        if (-Not $result.uniqueIdentifier) {
            Write-Error $result
        }
    }
}
