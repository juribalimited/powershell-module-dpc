<#

.SYNOPSIS
A sample script to query a CSV file for users and import
those users into Dashworks.

.DESCRIPTION
A sample script to query a CSV file for users and import
those users into Dashworks. Script will either update or create
the user.

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
$feed = Get-DwImportUserFeed @DashworksParams -Name $DwFeedName
# If it doesnt exist, create it
if (-Not $feed) {
    $feed = New-DwImportUserFeed @DashworksParams -Name $DwFeedName -Enabled $true
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
    Write-Progress -Activity "Importing Users to Dashworks" -Status ("Processing user: {0}" -f $uniqueIdentifier) -PercentComplete (($i/$csvFile.Count*100))

    $existingUser = Get-DwImportUser @DashworksParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier
    if ($existingUser) {
        $result = Set-DwImportUser @DashworksParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        $result = New-DwImportUser @DashworksParams -ImportId $importId -JsonBody $jsonBody
        #check result, for a new user we expect the return object to contain the user
        if (-Not $result.uniqueIdentifier) {
            Write-Error $result
        }
    }
}
