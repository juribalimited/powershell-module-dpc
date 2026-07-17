<#

.SYNOPSIS
A sample script to query a CSV file for devices and import
those devices into Juriba DPC.

.DESCRIPTION
A sample script to query a CSV file for devices and import
those devices into Juriba DPC. Script will either update or create
the device.

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$JuribaInstance,
    [Parameter(Mandatory=$true)]
    [string]$JuribaAPIKey,
    [Parameter(Mandatory=$true)]
    [string]$JuribaFeedName,
    [Parameter(Mandatory=$true)]
    [string]$Path
)

#Requires -Version 7
#Requires -Module @{ ModuleName = 'Juriba.DPC'; ModuleVersion = '0.0.14' }

$JuribaParams = @{
    Instance = $JuribaInstance
    APIKey = $JuribaAPIKey
}

# Get Juriba DPC feed
$feed = Get-JuribaImportDeviceFeed @JuribaParams -Name $JuribaFeedName
# If it doesnt exist, create it
if (-Not $feed) {
    $feed = New-JuribaImportDeviceFeed @JuribaParams -Name $JuribaFeedName -Enabled $true
}
$importId = $feed.id

Write-Information ("Using feed id {0}" -f $importId) -InformationAction Continue

# Get data from CSV file
$csvFile = Import-Csv -Path $Path

<# Optional Format File data
$columnsToRemove = @("ImportID")
#Validate that columns exist before removing
    foreach ($col in $columnsToRemove) {
        if ($csvFile[0].PSObject.Properties.Name -contains $col) {
            $csvFile | ForEach-Object { $_.PSObject.Properties.Remove($col) }
        }
        else {
            Write-Warning "Column '$col' not found in CSV. Skipping."
        }
    }

#add owner field.
$csvFile = $csvFile | Select-Object *,@{Name='owner'; Expression={"/imports/" + $ImportID + "/users/" + $_."User Principal Name"}}
foreach ($line in $csvFile) {
    $emptyline = "/imports/" + $ImportID + "/users/"
    if ($line.owner -eq $emptyline) {
        $line.owner = ''
    }
}
#>

$i = 0
foreach ($line in $csvFile) {
    $i++
    # convert line to json
    $jsonBody = $line | ConvertTo-Json
    $uniqueIdentifier = $line.uniqueIdentifier
    Write-Progress -Activity "Importing Devices to Juriba DPC" -Status ("Processing device: {0}" -f $uniqueIdentifier) -PercentComplete (($i/$csvFile.Count*100))

    $existingDevice = Get-JuribaImportDevice @JuribaParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier
    if ($existingDevice) {
        $result = Set-JuribaImportDevice @JuribaParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        $result = New-JuribaImportDevice @JuribaParams -ImportId $importId -JsonBody $jsonBody
        #check result, for a new device we expect the return object to contain the device
        if (-Not $result.uniqueIdentifier) {
            Write-Error $result
        }
    }
}
