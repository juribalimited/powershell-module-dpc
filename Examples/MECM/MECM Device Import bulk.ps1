<#

.SYNOPSIS
A sample script to query the MECM database for devices and import
those devices into Juriba.

.DESCRIPTION
A sample script to query the MECM database for devices and import
those devices into Juriba using the /$bulk endpoints. 
Script will either update or create the device.

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$JuribaInstance,
    [Parameter(Mandatory=$true)]
    [string]$APIKey,
    [Parameter(Mandatory=$true)]
    [string]$FeedName,
    [Parameter(Mandatory=$true)]
    [string]$MecmServerInstance,
    [Parameter(Mandatory=$true)]
    [string]$MecmDatabaseName,
    [Parameter(Mandatory=$true)]
    [pscredential]$MecmCredentials
)

#Requires -Version 7
#Requires -Module SqlServer
#Requires -Module Juriba.Platform

$JuribaParams = @{
    Instance = $JuribaInstance
    APIKey = $APIKey
}

$MecmParams = @{
    ServerInstance = $MecmServerInstance
    Database = $MecmDatabaseName
    Credential = $MecmCredentials
}

# Get DW feed
$feed = Get-JuribaImportDeviceFeed @JuribaParams -Name $FeedName
# If it doesnt exist, create it
if (-Not $feed) {
    $feed = New-JuribaImportDeviceFeed @JuribaParams -Name $FeedName -Enabled $true
}
$importId = $feed.id

Write-Information ("Using feed id {0}" -f $importId) -InformationAction Continue

# Run query against MECM database
$table = Invoke-Sqlcmd @MecmParams -InputFile "$PSScriptRoot\MECM Device Query.sql"

Write-Information ("MECM query returned {0} rows." -f $table.count) -InformationAction Continue

#get existing devices from Juriba
$existingDevices = Get-JuribaImportDevice @JuribaParams -ImportId $importId

#get list of new devices to be posted
$postDevices = $table | Where-Object {$_.UniqueIdentifier -notin $existingDevices}
Write-Information ("{0} devices to create." -f $postDevices.count) -InformationAction Continue
#get list of exsiting devices to be patched
$patchDevices = $table | Where-Object {$_.UniqueIdentifier -in $existingDevices}
Write-Information ("{0} devices to update." -f $patchDevices.count) -InformationAction Continue

# set size of batch, max 1000
$batchSize = 1000
Write-Information ("Using batch size {0}." -f $batchSize) -InformationAction Continue
$hasMore = $true

if ($postDevices) {
    for ($i = 0; $hasMore; $i=$i+$batchSize)
    {
        if ($postDevices[$i..($i+$batchSize-1)].count -eq 0)
        {
            $hasMore = $false
            Write-Information ("Finished create.") -InformationAction Continue
        }
        else {
            Write-Information ("Starting create batch {0}." -f (($i / $batchSize) + 1)) -InformationAction Continue
            $jsonBody = $postDevices[$i..($i+$batchSize-1)] | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors, OwnerDomain, OwnerUsername | ConvertTo-Json
            New-JuribaImportDevice @JuribaParams -ImportId $importId -JsonBody $jsonBody | Out-Null 
        }
    }
}

$hasMore = $true
if ($patchDevices) {
    for ($i = 0; $hasMore; $i=$i+$batchSize)
    {
        if ($patchDevices[$i..($i+$batchSize-1)].count -eq 0)
        {
            $hasMore = $false
            Write-Information ("Finished update.") -InformationAction Continue
        }
        else {
            Write-Information ("Starting update batch {0}." -f (($i / $batchSize) + 1)) -InformationAction Continue
            $jsonBody = $patchDevices[$i..($i+$batchSize-1)] | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors, OwnerDomain, OwnerUsername | ConvertTo-Json
            Set-JuribaImportDevice @JuribaParams -ImportId $importId -JsonBody $jsonBody | Out-Null 
        }
    }
}