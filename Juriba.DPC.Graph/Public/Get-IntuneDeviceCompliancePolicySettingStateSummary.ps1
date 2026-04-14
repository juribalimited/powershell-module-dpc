function Get-IntuneDeviceCompliancePolicySettingStateSummary {
<#
.SYNOPSIS
Retrieves compliance setting evaluation states for an Intune device policy.

.DESCRIPTION
Queries the Microsoft Graph v1.0 endpoint
`/deviceManagement/managedDevices/{deviceId}/deviceCompliancePolicyStates/{policyId}/settingStates`
to retrieve detailed compliance evaluation results for individual settings
within a specific Intune device compliance policy.

The function returns setting-level compliance state information for the
specified managed device and policy, automatically handling Microsoft Graph
pagination and returning the results as a System.Data.DataTable.

Nested or complex properties returned by Microsoft Graph are flattened and
stored as compressed JSON strings for downstream processing.

.PARAMETER AccessToken
A valid OAuth 2.0 bearer token for Microsoft Graph with permission to
read Intune device compliance data.

.PARAMETER DeviceId
The Intune managed device ID for which compliance setting states
should be retrieved.

.PARAMETER PolicyId
The Intune device compliance policy ID whose setting evaluation
states should be retrieved.

.PARAMETER Uri
Optional Microsoft Graph endpoint URI.

Defaults to:
`https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/'{DeviceId}'/deviceCompliancePolicyStates/'{PolicyId}'/settingStates`

This parameter is intended for advanced or testing scenarios.

.OUTPUTS
System.Data.DataTable

A DataTable where each row represents a single compliance policy setting
and its evaluation state for the specified device. Columns are created
dynamically based on properties returned by Microsoft Graph.

.EXAMPLE
$dt = Get-IntuneDeviceCompliancePolicySettingStateSummary `
    -AccessToken $AccessToken `
    -DeviceId $DeviceId `
    -PolicyId $PolicyId

Retrieves compliance setting evaluation states for a specific device
and compliance policy.

.EXAMPLE
Get-IntuneDeviceCompliancePolicySettingStateSummary `
    -AccessToken $AccessToken `
    -DeviceId $DeviceId `
    -PolicyId $PolicyId `
    -Verbose

Retrieves compliance setting states and outputs verbose paging information.

.NOTES
- Uses Microsoft Graph v1.0 compliance `settingStates` endpoint
- Data is device-specific and policy-specific
- Automatically follows @odata.nextLink for paging
- Nested objects are stored as JSON strings
- Intended for detailed Intune compliance reporting and Juriba imports
#>
    [OutputType([System.Data.DataTable])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceId,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PolicyId,
        [Parameter(Mandatory = $false)]
        [string]$Uri 
    )    

    begin {
        $dtResults = New-Object System.Data.DataTable
        $pageCount = 0
        if ([string]::IsNullOrWhiteSpace($Uri)) {
            $Uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$DeviceId/deviceCompliancePolicyStates/$PolicyId/settingStates"
        } 
    }

    process {
        do {
            if ([string]::IsNullOrWhiteSpace($Uri)) { break }
            $pageCount++
            Write-Verbose "Fetching page $pageCount from Graph API: $Uri"

            try {
                $devices = Invoke-RestMethod -Headers @{ Authorization = "Bearer $AccessToken" } -Uri $Uri -Method Get
            }
            catch {
                Write-Error "Failed to retrieve data from Graph API: $_"
                return
            }

            if (-not $devices.Value) { break }

            foreach ($entry in $devices.Value) {
                # Dynamically create columns
                foreach ($prop in $entry.PSObject.Properties.Name) {
                    if (-not $dtResults.Columns.Contains($prop)) {
                        $dtResults.Columns.Add($prop, [string]) | Out-Null
                    }
                }

                # Create new row and populate
                $dataRow = $dtResults.NewRow()
                foreach ($prop in $entry.PSObject.Properties.Name) {
                    $value = $entry.$prop
                    if ($null -eq $value) {
                        $dataRow[$prop] = [DBNull]::Value
                    }
                    elseif ($value -is [Object[]]) {
                        $dataRow[$prop] = ($value | ConvertTo-Json -Compress)
                    }
                    else {
                        $dataRow[$prop] = $value
                    }
                }
                $dtResults.Rows.Add($dataRow)
            }
            
            # Check if there is more data
            if ($devices.PSObject.Properties.Name -contains '@odata.nextLink' -and $devices.'@odata.nextLink') {
                $Uri = $devices.'@odata.nextLink'
            } else {
                $Uri = $null
            }
        } while ($null -ne $Uri)
    }

    end {
        Write-Verbose "Returning DataTable with $($dtResults.Rows.Count) rows across $pageCount pages."
        return $dtResults
    }
}