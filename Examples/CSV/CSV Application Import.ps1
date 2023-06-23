<#
.SYNOPSIS
A sample script to query a CSV file for applications and import
those devices into Juriba.

.DESCRIPTION
A sample script to query a CSV file for applications and import
those applications into Juriba. The script will either update or create
the application.

.Parameter Instance
The URI to the Juriba instance being examined.

.Parameter APIKey
The API Key for a user with access to the required resources.

.Parameter FeedName
The name of the feed to be searched for and used. If this does not exist, it will create it.

.Parameter Path
The full path name of where the CSV file is located, including the file name and extension. For
example, C:\Temp\Applications.csv
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$Instance,
    [Parameter(Mandatory=$true)]
    [string]$APIKey,
    [Parameter(Mandatory=$true)]
    [string]$FeedName,
    [Parameter(Mandatory=$true)]
    [string]$Path
)

#Requires -Version 7
#Requires -Module @{ ModuleName = 'Juriba.Platform'; ModuleVersion = '0.0.38.0' }

$DashworksParams = @{
    Instance = $Instance
    APIKey = $APIKey
}

# Get Juriba Feed
$feed = Get-JuribaImportApplicationFeed @DashworksParams -Name $FeedName

# If it doesnt exist, create it
if (-Not $feed) {
    $feed = New-JuribaImportApplicationFeed @DashworksParams -Name $FeedName -Enabled $true
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
    Write-Progress -Activity "Importing applications to Juriba" -Status ("Processing Application: {0}" -f $uniqueIdentifier) -PercentComplete (($i/$csvFile.Count*100))

    $existingApplication = Get-JuribaImportApplication @DashworksParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier -ErrorAction SilentlyContinue
    if ($existingApplication) {
        $result = Set-JuribaImportApplication @DashworksParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        $result = New-JuribaImportApplication @DashworksParams -ImportId $importId -JsonBody $jsonBody
        #check result, for a new application we expect the return object to contain the application
        if (-Not $result.uniqueIdentifier) {
            Write-Error $result
        }
    }
}