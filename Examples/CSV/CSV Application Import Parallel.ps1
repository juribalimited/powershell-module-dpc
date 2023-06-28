<#
.SYNOPSIS
A sample script to query a CSV file for applications and import
those applications into Juriba.

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

# build hashtable for job
$origin = @{}
$csvFile | Foreach-Object {$origin.($_.uniqueIdentifier) = 0}

# create synced hashtable
$sync = [System.Collections.Hashtable]::Synchronized($origin)

$job = $csvFile | ForEach-Object -AsJob -ThrottleLimit 16 -Parallel {
    $syncCopy = $using:sync

    Import-Module .\Juriba.Platform\Juriba.Platform.psd1
    # convert table row to json, exclude attributes we dont need
    $jsonBody = $_ | ConvertTo-Json
    $uniqueIdentifier = $_.uniqueIdentifier

    $existingApplication = Get-JuribaImportApplication @using:DashworksParams -ImportId @using:importId -UniqueIdentifier $uniqueIdentifier -ErrorAction SilentlyContinue
    if ($existingApplication) {
        $result = Set-JuribaImportApplication @using:DashworksParams -ImportId @using:importId -UniqueIdentifier $uniqueIdentifier -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        $result = New-JuribaImportApplication @using:DashworksParams -ImportId @using:importId -JsonBody $jsonBody
        #check result, for a new application we expect the return object to contain the application
        if (-Not $result.uniqueIdentifier) {
            Write-Error $result
        }
    }

    # Mark process as completed
    $syncCopy[$_.uniqueIdentifier] = 1 
}

while($job.State -eq 'Running')
{
    $pctComplete = (($sync.GetEnumerator().Where({$_.Value -eq 1}).Count) / $sync.Count) * 100
    Write-Progress -Activity "Importing Applications to Dashworks" -PercentComplete $pctComplete

    # Wait to refresh to not overload gui
    Start-Sleep -Seconds 0.25
}