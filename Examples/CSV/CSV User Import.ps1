<#
.SYNOPSIS
A sample script to query a CSV file for users and import
those users into Juriba DPC.
.DESCRIPTION
A sample script to query a CSV file for users and import
those users into Juriba DPC. Script will either update or create
the user.
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
$feed = Get-JuribaImportUserFeed @JuribaParams -Name $JuribaFeedName
# If it doesnt exist, create it
if (-Not $feed) {
    $feed = New-JuribaImportUserFeed @JuribaParams -Name $JuribaFeedName -Enabled $true
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
#>

$i = 0
foreach ($line in $csvFile) {
    $i++
    # convert line to json
    $jsonBody = $line | ConvertTo-Json
    $username = $line.username
    $UniqueIdentifier = $line.UniqueIdentifier
    Write-Progress -Activity "Importing Users to Juriba DPC" -Status ("Processing User: {0}" -f $username) -PercentComplete (($i/$csvFile.Count*100))

    $existingUser = Get-JuribaImportUser @JuribaParams -ImportId $importId -Username $username
    if ($existingUser) {
        $result = Set-JuribaImportUser @JuribaParams -ImportId $importId -UniqueIdentifier $UniqueIdentifier -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        $result = New-JuribaImportUser @JuribaParams -ImportId $importId -JsonBody $jsonBody
        #check result, for a new user we expect the return object to contain the user
        if (-Not $result.username) {
            Write-Error $result
        }
    }
}
