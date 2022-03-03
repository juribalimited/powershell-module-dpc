<#

.SYNOPSIS
A sample script to query the MECM database for Packages (Packaged Applications) and import
those as applications into Dashworks.

.DESCRIPTION
A sample script to query the MECM database for Packages (Packaged Applications) and import
those as applications into Dashworks. Script will either update or create the applications.

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
    [string]$MecmServerInstance,
    [Parameter(Mandatory=$true)]
    [string]$MecmDatabaseName,
    [Parameter(Mandatory=$true)]
    [pscredential]$MecmCredentials
)

#Requires -Version 7
#Requires -Module SqlServer
#Requires -Module @{ ModuleName = 'Juriba.Dashworks'; ModuleVersion = '0.0.14' }

$DashworksParams = @{
    Instance = $DwInstance
    Port = $DwPort
    APIKey = $DwAPIKey
}

$MecmParams = @{
    ServerInstance = $MecmServerInstance
    Database = $MecmDatabaseName
    Credential = $MecmCredentials
}

# Get DW feed
$feed = Get-DwImportDeviceFeed @DashworksParams -FeedName $DwFeedName
# If it doesnt exist, create it
if (-Not $feed) {
    $feed = New-DwImportDeviceFeed @DashworksParams -Name $DwFeedName -Enabled $true
}
$importId = $feed.id

Write-Information ("Using feed id {0}" -f $importId) -InformationAction Continue

# Run query against MECM database
$table = Invoke-Sqlcmd @MecmParams -InputFile "$PSScriptRoot\MECM Pkg Application Query.sql"

Write-Information ("MECM query returned {0} rows." -f $table.count) -InformationAction Continue

$i = 0
foreach ($row in $table){
    $i++
    # convert table row to json, exclude attributes we dont need
    $jsonBody = $row | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
    $uniqueIdentifier = $row.uniqueIdentifier
    Write-Progress -Activity "Importing Applications to Dashworks" -Status ("Processing application: {0}" -f $uniqueIdentifier) -PercentComplete (($i/$table.Count)*100)

    $existingApp = Get-DwImportApplication @DashworksParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier
    if ($existingApp) {
        $result = Set-DwImportApplication @DashworksParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        $result = New-DwImportApplication @DashworksParams -ImportId $importId -JsonBody $jsonBody
        #check result, for a new application we expect the return object to contain the application
        if (-Not $result.uniqueIdentifier) {
            Write-Error $result
        }
    }
}
