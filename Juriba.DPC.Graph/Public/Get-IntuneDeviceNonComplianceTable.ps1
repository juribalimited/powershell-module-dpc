function Get-IntuneDeviceNonComplianceTable {
<#
.SYNOPSIS
Builds a summary table of non-compliant Intune devices and policies.

.DESCRIPTION
Constructs a System.Data.DataTable summarising non-compliant Intune
device compliance policies for a set of managed devices.

For each device supplied, the function retrieves device compliance
policy state information using Get-IntuneDeviceCompliancePolicyState,
filters out compliant policies and the default compliance policy, and
produces a per-device summary listing non-compliant policies and a
corresponding count.

The resulting table is intended for reporting, analysis, or downstream
import into systems such as Juriba.

.PARAMETER AccessToken
A valid OAuth 2.0 bearer token for Microsoft Graph with permission to
read Intune device compliance policy state data.

.PARAMETER Devices
An array of device objects containing at least an `id` property
representing the Intune managed device ID.

These devices are typically obtained from a prior Intune device or
compliance discovery step.

.OUTPUTS
System.Data.DataTable

Returns a DataTable with one row per device containing the following
columns:

- deviceUniqueIdentifier
- nonCompliantPolicies
- nonCompliantPolicyCount

.EXAMPLE
$dt = Get-IntuneDeviceNonComplianceTable `
    -AccessToken $AccessToken `
    -Devices $Devices

Builds a table summarising non-compliant policies for the supplied devices.

.EXAMPLE
$devices = Get-IntuneDevice -AccessToken $AccessToken
$nonComplianceTable = Get-IntuneDeviceNonComplianceTable `
    -AccessToken $AccessToken `
    -Devices $devices

Retrieves Intune devices and generates a non-compliance summary table.

.NOTES
- Depends on Get-IntuneDeviceCompliancePolicyState for compliance data
- Policies with state "compliant" are excluded
- The "Default Device Compliance Policy" is excluded by design
- Intended for Intune compliance reporting and Juriba imports
#>
    [CmdletBinding()]
    [OutputType([System.Data.DataTable])]
    param (
        [Parameter(Mandatory)]
        [string]$AccessToken,
        [Parameter(Mandatory)]
        [array]$Devices
    )

    # Build output DataTable
    $deviceAppsTable = New-Object System.Data.DataTable
    $deviceAppsTable.Columns.Add("deviceUniqueIdentifier", [string]) | Out-Null
    $deviceAppsTable.Columns.Add("nonCompliantPolicies", [string]) | Out-Null
    $deviceAppsTable.Columns.Add("nonCompliantPolicyCount", [string]) | Out-Null

    foreach ($ncDevice in $Devices) {

        $deviceId = $ncDevice.id

        # Pull device apps from Intune
        $devicePolicies = Get-IntuneDeviceCompliancePolicyState -AccessToken $accessToken -DeviceId $deviceId
        $nonCompliantPolicies = $devicePolicies | Where-Object -FilterScript {$_.state -ne "compliant" -and $_.displayName -ne "Default Device Compliance Policy"} | Select-Object -Property @{Name = "deviceId"; Expression = {$deviceId}}, id, displayName -Unique
        $policies = $nonCompliantPolicies | Group-Object -Property deviceId | Select-Object @{Name = "nonCompliantPolicies"; Expression = {($_.Group.displayName -join ', ')}}
        $policyCount = $nonCompliantPolicies | Group-Object -Property deviceId | Select-Object @{Name = "nonCompliantPolicyCount"; Expression = {$_.Group.id.Count}}

        foreach ($device in $policies) {
            $row = $deviceAppsTable.NewRow()
            $row.deviceUniqueIdentifier = $deviceId
            $row.nonCompliantPolicies = $policies
            $row.nonCompliantPolicyCount = $policyCount

            $deviceAppsTable.Rows.Add($row)
        }
    }

    $PSCmdlet.WriteObject($deviceAppsTable, $false)
}