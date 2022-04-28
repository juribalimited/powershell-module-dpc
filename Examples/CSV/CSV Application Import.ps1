<#

.SYNOPSIS
A sample script to query a CSV file for applications and import
those applications into Dashworks.

.DESCRIPTION
A sample script to query a CSV file for applications and import
those applications into Dashworks. Script will either update or create
the Application.

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
$feed = Get-DwImportApplicationFeed @DashworksParams -Name $DwFeedName
# If it doesnt exist, create it
if (-Not $feed) {
    $feed = New-DwImportApplicationFeed @DashworksParams -Name $DwFeedName -Enabled $true
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
    Write-Progress -Activity "Importing applications to Dashworks" -Status ("Processing Application: {0}" -f $uniqueIdentifier) -PercentComplete (($i/$csvFile.Count*100))

    $existingApplication = Get-DwImportApplication @DashworksParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier
    if ($existingApplication) {
        $result = Set-DwImportApplication @DashworksParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        $result = New-DwImportApplication @DashworksParams -ImportId $importId -JsonBody $jsonBody
        #check result, for a new Application we expect the return object to contain the Application
        if (-Not $result.uniqueIdentifier) {
            Write-Error $result
        }
    }
}
