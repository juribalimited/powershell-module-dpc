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
<#
    .PARAMETER JuribaInstance
    Juriba Platform instance.
    .PARAMETER JuribaAPIKey
    Juriba Platform APIKey.
    .PARAMETER JuribaFeedName
    Name of the data import feed (Must be of type user import).
    .PARAMETER Path
    Path to CSV file containing groups details (refer to swagger docs for properties).
#>

#Requires -Version 7
#Requires -Module @{ ModuleName = 'Juriba.Platform'; ModuleVersion = '0.0.39.0' }

$DashworksParams = @{
    Instance = $JuribaInstance
    APIKey = $JuribaAPIKey
}

# Get Juriba User Import feed
$feed = Get-JuribaImportUserFeed @DashworksParams -Name $JuribaFeedName
# If it doesnt exist, create it
if (-Not $feed.id) {
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
    $groupname = $line.Name
    $groupidentifier = $line.UniqueIdentifier
    Write-Progress -Activity "Importing groups to Juriba Platform" -Status ("Processing group: {0}" -f $groupname) -PercentComplete (($i/$csvFile.Count*100))

    $existinggroup = Get-JuribaImportGroup @DashworksParams -ImportId $importId -Name $groupname -ErrorAction SilentlyContinue 
    if ($existinggroup) {
        Write-Information ("Updating existing group: {0}" -f $groupname) -InformationAction Continue
        $updatedJsonBody = ($jsonBody | ConvertFrom-Json) | Select-Object -ExcludeProperty UniqueIdentifier
        $result = Set-JuribaImportGroup @DashworksParams -ImportId $importId -UniqueIdentifier $groupidentifier -JsonBody ($updatedJsonBody | ConvertTo-Json)
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        Write-Information ("Creating new group: {0}" -f $groupname) -InformationAction Continue
        $result = New-JuribaImportGroup @DashworksParams -ImportId $importId -JsonBody $jsonBody
        #check result, for a new group we expect the return object to contain the group
        if (-Not $result.name) {
            Write-Error "Group not created successfully."
        }
    }
}