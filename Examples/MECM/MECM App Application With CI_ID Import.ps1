<#

.SYNOPSIS
A sample script to query the MECM database for Applications and import
those as applications into Dashworks. Requires the following Custom Fields to already be onboarded and created:
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'CI_UniqueID' -CSVColumnHeader 'CI_UniqueID' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'PackageID' -CSVColumnHeader 'PackageID' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'

.DESCRIPTION
A sample script to query the MECM database for Applications and import
those as applications into Dashworks. Script will either update or create the applications.

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
$feed = Get-DwImportDeviceFeed @DashworksParams -Name $DwFeedName
# If it doesnt exist, create it
if (-Not $feed) {
    $feed = New-DwImportDeviceFeed @DashworksParams -Name $DwFeedName -Enabled $true
}
$importId = $feed.id

Write-Information ("Using feed id {0}" -f $importId) -InformationAction Continue

# Run query against MECM database
$table = Invoke-Sqlcmd @MecmParams -InputFile "$PSScriptRoot\MECM App Application Query With CI_ID.sql"

Write-Information ("MECM query returned {0} rows." -f $table.count) -InformationAction Continue

$i = 0
foreach ($row in $table){
    $i++
    # convert table row to json, exclude attributes we dont need
    $appObj = $row | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors #| ConvertTo-Json -EscapeHandling EscapeNonAscii
    $customFieldList = New-Object System.Collections.Generic.List[Object]
    
    $customFieldList += @{
        Name = 'CI_UniqueID'
        Value= $appObj.CI_UniqueID
    }
    $customFieldList += @{
        Name = 'PackageID'
        Value= $appObj.PackageID
    }

    $appObj | Add-Member -MemberType NoteProperty -Name "customFieldValues" -Value $customFieldList
    $jsonBody = $appObj | Select-Object -ExcludeProperty CI_UniqueID, PackageID | ConvertTo-Json

    $uniqueIdentifier = $row.UniqueIdentifier

    Write-Progress -Activity "Importing Applications to Juriba platform" -Status ("Processing application: {0}" -f $uniqueIdentifier) -PercentComplete (($i/$table.Count)*100)
    $existingApp = Get-DwImportApplication @DashworksParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier
    if ($existingApp) {
        Write-Information ("Existing app {0} found." -f $uniqueIdentifier) -InformationAction Continue
        $result = Set-DwImportApplication @DashworksParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        Write-Information ("Creating new app in Juriba Platform: {0}" -f $appObj.Name) -InformationAction Continue
        $result = New-DwImportApplication @DashworksParams -ImportId $importId -JsonBody $jsonBody
        #check result, for a new application we expect the return object to contain the application
        if (-Not $result.uniqueIdentifier) {
            Write-Error $result
        }
    }
}
