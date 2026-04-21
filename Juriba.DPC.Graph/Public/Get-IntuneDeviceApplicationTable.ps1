function Get-IntuneDeviceApplicationTable {
<#
.SYNOPSIS
Builds a Juriba-ready device-to-application mapping table for Intune devices.

.DESCRIPTION
Constructs a System.Data.DataTable representing the relationship between
Intune-managed devices and their associated applications, including
installation state information.

For each supplied device, the function retrieves Intune application intent
and state data by invoking Get-IntuneDeviceApplication (Microsoft Graph beta),
then transforms the results into a flattened, Juriba-compatible table.

The output is intended to be used directly as an import source for Juriba
device application data.

.PARAMETER AccessToken
A valid OAuth 2.0 bearer token for Microsoft Graph with permission to
read Intune device and application state data.

.PARAMETER OwnedDevices
An array of device objects containing at least the following properties:
- uniqueIdentifier (Intune managed device ID)
- owner (user reference from which the user ID can be derived)

These objects are typically produced by a prior Intune or Entra ID
device import step.

.PARAMETER ImportId
A unique identifier representing the current Juriba import operation.
This value is applied to all generated rows to associate them with a
specific import batch.

.OUTPUTS
System.Data.DataTable

Returns a DataTable with one row per device-application relationship,
containing the following columns:

- deviceUniqueIdentifier
- applicationUniversalDataImportId
- AppUniqueIdentifier
- entitled
- installed

.EXAMPLE
$deviceAppTable = Get-IntuneDeviceApplicationTable `
    -AccessToken $AccessToken `
    -OwnedDevices $Devices `
    -ImportId $ImportId

Builds a Juriba-compatible device application table for the supplied devices.

.EXAMPLE
$devices = Get-IntuneDevice -AccessToken $AccessToken
$deviceAppTable = Get-IntuneDeviceApplicationTable `
    -AccessToken $AccessToken `
    -OwnedDevices $devices `
    -ImportId $ImportId

Retrieves Intune devices and constructs a device-to-application mapping
table for Juriba import.

.NOTES
- Relies on Get-IntuneDeviceApplication (Microsoft Graph beta)
- Application state is evaluated per user-device pair
- Installed state is inferred from Intune installState value
- Intended as a preprocessing step before importing application
  assignment data into Juriba
#>
    [CmdletBinding()]
    [OutputType([System.Data.DataTable])]
    param (
        [Parameter(Mandatory)]
        [string]$AccessToken,
        [Parameter(Mandatory)]
        [array]$OwnedDevices,
        [Parameter(Mandatory)]
        [string]$ImportId
    )

    # Build output DataTable
    $deviceAppsTable = New-Object System.Data.DataTable
    $deviceAppsTable.Columns.Add("deviceUniqueIdentifier", [string]) | Out-Null
    $deviceAppsTable.Columns.Add("applicationUniversalDataImportId", [string]) | Out-Null
    $deviceAppsTable.Columns.Add("AppUniqueIdentifier", [string]) | Out-Null
    $deviceAppsTable.Columns.Add("entitled", [boolean]) | Out-Null
    $deviceAppsTable.Columns.Add("installed", [boolean]) | Out-Null

    foreach ($device in $OwnedDevices) {

        $deviceId = $device.uniqueIdentifier
        $userId   = ($device.owner -split '/')[ -1 ]

        # Pull device apps from Intune
        $deviceApps = Get-IntuneDeviceApplication `
                        -AccessToken $AccessToken `
                        -UserId $userId `
                        -DeviceId $deviceId |
                       Select-Object -ExpandProperty mobileAppList

        foreach ($app in $deviceApps) {
            $row = $deviceAppsTable.NewRow()
            $row.deviceUniqueIdentifier            = $deviceId
            $row.applicationUniversalDataImportId  = $ImportId
            $row.AppUniqueIdentifier               = $app.applicationId
            $row.entitled                          = $true
            $row.installed                         = ($app.installState -eq "installed")

            $deviceAppsTable.Rows.Add($row)
        }
    }

    $PSCmdlet.WriteObject($deviceAppsTable, $false)
}