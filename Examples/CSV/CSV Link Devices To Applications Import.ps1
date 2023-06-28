<#
.SYNOPSIS
A sample script to query a CSV file for linking Devices and 
Applications into Juriba.

.DESCRIPTION
A sample script to query a CSV file for linking Devices and 
Applications into Juriba. The script will only update existing Devices
and Application.

.Parameter Instance
The URI to the Juriba instance being examined.

.Parameter APIKey
The API Key for a user with access to the required resources.

.Parameter DeviceFeedName
The name of the feed to be searched for and used. If this does not exist, the process will stop.

.Parameter AppFeedName
The name of the feed to be searched for and used. If this does not exist, the process will stop.

.Parameter Path
The full path name of where the CSV file is located, including the file name and extension. For
example, C:\Temp\DevicesToApplications.csv. This process is designed off having the Device 
Hostname and Application UniqueIdentifier to map the them together.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$Instance,
    [Parameter(Mandatory=$true)]
    [string]$APIKey,
    [Parameter(Mandatory=$true)]
    [string]$DeviceFeedName,
    [Parameter(Mandatory=$true)]
    [string]$AppFeedName,
    [Parameter(Mandatory=$true)]
    [string]$Path
)

#Requires -Version 7
#Requires -Module @{ ModuleName = 'Juriba.Platform'; ModuleVersion = '0.0.38.0' }

$DashworksParams = @{
    Instance = $Instance
    APIKey = $APIKey
}

# Get Juriba Device Feed
$Devfeed = Get-JuribaImportDeviceFeed @DashworksParams -Name $DeviceFeedName

# If it doesnt exist, stop the process
if ($Devfeed) {
    $DevimportId = $Devfeed.id
    Write-Output "Using Device Feed ID $DevimportId"
}
else{
    Write-Output "PROCESS CANCELLED - Device Feed $DeviceFeedName does not exist"
    Exit
}

# Get Juriba Application Feed
$Appfeed = Get-JuribaImportApplicationFeed @DashworksParams -Name $AppFeedName

# If it doesnt exist, stop the process
if ($Appfeed) {
    $AppimportId = $Appfeed.id
    Write-Output "Using Application Feed ID $AppimportId"
}
else{
    Write-Output "PROCESS CANCELLED - Application Feed $AppFeedName does not exist"
    Exit
}

#Get data from CSV file and add required fields
$csvFile = Import-Csv -Path $Path
Write-Output "CSV File Imported"

#Add the required fields for importing
$dataTable = New-Object System.Data.DataTable
$dataTable.Columns.Add("Hostname", [string]) | Out-Null
$dataTable.Columns.Add("applicationBusinessKey", [string]) | Out-Null
$dataTable.Columns.Add("applicationDistHierId", [string]) | Out-Null
$dataTable.Columns.Add("installed", [string]) | Out-Null
$dataTable.Columns.Add("entitled", [string]) | Out-Null
$dataTable.Columns.Add("installDateKey", [string]) | Out-Null

foreach($Row in $csvFile){
    $NewRow = $null
    $NewRow = $dataTable.NewRow()
    $NewRow.Hostname = $Row.Hostname
    $NewRow.applicationBusinessKey = $Row.ApplicationUID
    $NewRow.applicationDistHierId = $AppimportId
    $NewRow.installed = "True"
    $NewRow.entitled = "False"
    $NewRow.installDateKey = $Null
    $dataTable.Rows.Add($NewRow)
}

#Get the Devices to update
Write-Output "Importing Devices to process"
$Devices = Get-JuribaImportDevice -Instance $Instance -APIKey $APIKey -ImportId $DevImportID -InfoLevel "Full"
Write-Output "Devices Imported, linking Apps to Devices"

#Join the Devices and Apps ready for processing
Foreach ($device in $Devices){
    $dvAppsTable = New-Object System.Data.DataView($dataTable)
    $dvAppsTable.RowFilter="hostname='$($Device.hostname)'"
    Write-Progress -Activity "Linking Apps to Devices" -Status ("Processing Device: {0}" -f $device.hostname) -PercentComplete (($i/$Devices.Count*100))
 
    $applicationsJSON = @()
    ($dvAppsTable | Select-Object -Property applicationBusinessKey,applicationDistHierId,entitled,installed) | ForEach-Object {
        $AppObject = "" | select-object applicationBusinessKey,applicationDistHierId,entitled,installed
        $AppObject.applicationDistHierId=$_.applicationDistHierId
        $AppObject.applicationBusinessKey=$_.applicationBusinessKey
        $AppObject.entitled=$_.entitled
        $AppObject.installed=$_.installed
        $applicationsJSON += $AppObject
    }

    #Convert the results to JSON
    $Device.Applications = $applicationsJSON
    $JSONBody = $Device | ConvertTo-Json -Depth 5

    #Update the existing Devices to add the Apps
    Try{
        $result = Set-JuribaImportDevice -ImportId $DevImportID -UniqueIdentifier $Device.UniqueIdentifier -JsonBody $JSONBody -Instance $Instance -APIKey $APIKey
        Write-Output "$($Device.UniqueIdentifier) Completed Successfully"
    }
    Catch{
        Write-Output "$($Device.UniqueIdentifier) Did NOT Completed Successfully"
    }
}
Write-Output "***** Import Completed *****"