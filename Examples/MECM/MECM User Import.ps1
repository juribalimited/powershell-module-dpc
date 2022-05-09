<#

.SYNOPSIS
A sample script to query the MECM database for users and import
those users into Dashworks.

.DESCRIPTION
A sample script to query the MECM database for users and import
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
    [string]$MecmServerInstance,
    [Parameter(Mandatory=$true)]
    [string]$MecmDatabaseName,
    [Parameter(Mandatory=$true)]
    [pscredential]$MecmCredentials
)

#Requires -Version 7
#Requires -Module SqlServer
#Requires -Module Juriba.Dashworks

$DashworksParams = @{
    Instance = $DwInstance
    APIKey = $DwAPIKey
}

$MecmParams = @{
    ServerInstance = $MecmServerInstance
    Database = $MecmDatabaseName
    Credential = $MecmCredentials
}

# Get DW feed
$feed = Get-DwImportUserFeed @DashworksParams -Name $DwFeedName
# If it doesnt exist, create it
if (-Not $feed) {
    $feed = New-DwImportUserFeed @DashworksParams -Name $DwFeedName -Enabled $true
}
$importId = $feed.id

Write-Information ("Using feed id {0}" -f $importId) -InformationAction Continue

# Run query against MECM database
$table = Invoke-Sqlcmd @MecmParams -InputFile "$PSScriptRoost\MECM User Query.sql"

Write-Information ("MECM query returned {0} rows." -f $table.count) -InformationAction Continue

$i = 0
foreach ($row in $table){
    $i++
    # convert table row to json, exclude attributes we dont need
    $jsonBody = $row | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
    $username = $row.username

    Write-Progress -Activity "Importing Users to Dashworks" -Status ("Processing user: {0}" -f $username) -PercentComplete (($i/$table.Count*100))

    $existingUser = Get-DwImportUser @DashworksParams -ImportId $importId -Username $username
    if ($existingUser) {
        $result = Set-DwImportUser @DashworksParams -ImportId $importId -Useranme $username -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        $result = New-DwImportUser @DashworksParams -ImportId $importId -JsonBody $jsonBody
        #check result, for a new user we expect the return object to contain the user
        if (-Not $result.username) {
            Write-Error $result
        }
    }
}
