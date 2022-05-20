<#

.SYNOPSIS
A sample script to query the MECM database for devices and import
those devices into Dashworks.

.DESCRIPTION
A sample script to query the MECM database for devices and import
those devices into Dashworks. Script will either update or create
the device.

This script gives an example of how the Foreach-Object Parallel feature
of PowerShell can be used to make parallel calls to the API in order
to speed up the import of a large number of devices.

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
$table = Invoke-Sqlcmd @MecmParams -InputFile "$PSScriptRoot\MECM Device Query mstest.sql"

Write-Information ("MECM query returned {0} rows." -f $table.count) -InformationAction Continue

# build hashtable for job
$origin = @{}
$table | Foreach-Object {$origin.($_.uniqueIdentifier) = 0}

# create synced hashtable
$sync = [System.Collections.Hashtable]::Synchronized($origin)

$job = $table | ForEach-Object -AsJob -ThrottleLimit 16 -Parallel {
    $syncCopy = $using:sync

    Import-Module Juriba.Dashworks
    # convert table row to json, exclude attributes we dont need
    $jsonBody = $_ | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors, OwnerDomain, OwnerUsername | ConvertTo-Json
    $uniqueIdentifier = $_.uniqueIdentifier

    $existingDevice = Get-DwImportDevice @using:DashworksParams -ImportId $using:importId -UniqueIdentifier $uniqueIdentifier
    if ($existingDevice) {
        $result = Set-DwImportDevice @using:DashworksParams -ImportId $using:importId -UniqueIdentifier $uniqueIdentifier -JsonBody $jsonBody
        # check result, for an update we are expecting status code 204
        if ($result.StatusCode -ne 204) {
            Write-Error $result
        }
    }
    else {
        $result = New-DwImportDevice @using:DashworksParams -ImportId $using:importId -JsonBody $jsonBody
        # check result, for a new device we expect the return object to contain the device
        if ($result -And -Not $result.uniqueIdentifier) {
            Write-Error $result
        }
    }
    # Mark process as completed
    $syncCopy[$_.uniqueIdentifier] = 1
}


while($job.State -eq 'Running')
{
    $pctComplete = (($sync.GetEnumerator().Where({$_.Value -eq 1}).Count) / $sync.Count) * 100
    Write-Progress -Activity "Importing Devices to Dashworks" -PercentComplete $pctComplete

    # Wait to refresh to not overload gui
    Start-Sleep -Seconds 0.25
}


