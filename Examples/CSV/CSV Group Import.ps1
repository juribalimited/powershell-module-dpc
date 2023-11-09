<#
.SYNOPSIS
A sample script to query a CSV file for groups and import
those groups into Juriba Platform.
.DESCRIPTION
A sample script to query a CSV file for groups and import
those groups into Juriba Platform. Script will either update or create
the group.
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
#Requires -Module @{ ModuleName = 'Juriba.Platform'; ModuleVersion = '0.0.39.0' }

$DashworksParams = @{
    Instance = $JuribaInstance
    APIKey = $JuribaAPIKey
}

# Get Juriba User Import feed
$feed = Get-JuribaImportUserFeed @DashworksParams -Name $JuribaFeedName
# If it doesnt exist, create it
if (-Not $feed) {
    $feed = New-JuribaImportUserFeed @DashworksParams -Name $JuribaFeedName -Enabled $true
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
    $jsonBody
    $groupname = $line.Name
    Write-Progress -Activity "Importing groups to Juriba Platform" -Status ("Processing group: {0}" -f $groupname) -PercentComplete (($i/$csvFile.Count*100))

    $existinggroup = Get-JuribaImportGroup @DashworksParams -ImportId $importId -Name $groupname -ErrorAction SilentlyContinue 
    if ($existinggroup) {
        $result = Set-JuribaImportGroup @DashworksParams -ImportId $importId -UniqueIdentifier $groupname -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        $result = New-JuribaImportGroup @DashworksParams -ImportId $importId -JsonBody $jsonBody
        #check result, for a new group we expect the return object to contain the group
        if (-Not $result.groupname) {
            Write-Error $result
        }
    }
}