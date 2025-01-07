<#

.SYNOPSIS
A sample script to query the MECM database for devices and import
those devices into Dashworks.

.DESCRIPTION
A sample script to query the MECM database for devices and import
those devices into Dashworks. Script will either update or create
the device.

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
$feed = Get-JuribaImportDeviceFeed @DashworksParams -Name $DwFeedName
# If it doesnt exist, create it
if (-Not $feed) {
    $feed = New-JuribaImportDeviceFeed @DashworksParams -Name $DwFeedName -Enabled $true
}
$importId = $feed.id

Write-Information ("Using feed id {0}" -f $importId) -InformationAction Continue

# Run query against MECM database
$table = Invoke-Sqlcmd @MecmParams -InputFile "$PSScriptRoot\MECM Device Query.sql"

Write-Information ("MECM query returned {0} rows." -f $table.count) -InformationAction Continue

$i = 0
foreach ($row in $table){
    $i++
    # convert table row to json, exclude attributes we dont need
    $jsonBody = $row | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors, OwnerDomain, OwnerUsername | ConvertTo-Json
    $uniqueIdentifier = $row.uniqueIdentifier

    $uniqueIdentifier = $row.uniqueIdentifier

    # Generate a random 5-digit number
    $newLastFiveDigits = Get-Random -Minimum 10000 -Maximum 99999;  
    # Replace the last five digits with the new ones - otherwise we get 409 error
    $uniqueIdentifier = $uniqueIdentifier.Substring(0, $uniqueIdentifier.Length - 5)+ $newLastFiveDigits;

    ($jsonBody | ConvertFrom-Json).uniqueIdentifier  = $uniqueIdentifier;   
    $jsonBody = ($jsonBody | ConvertFrom-Json)
    $jsonBody.uniqueIdentifier = $uniqueIdentifier
    $jsonBody = ($jsonBody | ConvertTo-Json)

    Write-Progress -Activity "Importing Devices to Dashworks" -Status ("Processing device: {0}" -f $uniqueIdentifier) -PercentComplete (($i/$table.Count*100))

    $existingDevice = Get-JuribaImportDevice @DashworksParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier
    if ($existingDevice) {
        $result = Set-DwImportDevice @DashworksParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        $result = New-DwImportDevice @DashworksParams -ImportId $importId -JsonBody $jsonBody
        #check result, for a new device we expect the return object to contain the device
        if (-Not $result.uniqueIdentifier) {
            Write-Error $result
        }
    }
}
