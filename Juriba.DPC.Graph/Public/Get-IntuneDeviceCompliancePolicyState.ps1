function Get-IntuneDeviceCompliancePolicyState {
<#
.SYNOPSIS
Retrieves Intune device compliance policy evaluation states for a managed device.

.DESCRIPTION
Queries the Microsoft Graph `/deviceManagement/managedDevices/{id}/deviceCompliancePolicyStates`
v1.0 endpoint to retrieve compliance policy evaluation results for a specific
Intune-managed device.

Each returned entry represents the evaluation state of a single compliance
policy as applied to the device, including status and last evaluation details.
The function automatically handles Graph API pagination and returns the full
result set as a System.Data.DataTable.

Any nested or complex properties are flattened and stored as compressed JSON
strings to preserve the original data for downstream processing, such as
importing compliance state data into Juriba.

.PARAMETER AccessToken
A valid OAuth 2.0 bearer token for Microsoft Graph with permission to
read Intune device compliance policy state data.

.PARAMETER DeviceId
The Intune managed device ID for which compliance policy states
should be retrieved.

.OUTPUTS
System.Data.DataTable

A DataTable where each row represents the evaluation state of a single
Intune compliance policy for the specified device. Columns are created
dynamically based on the properties returned by Microsoft Graph.

.EXAMPLE
$dtPolicyStates = Get-IntuneDeviceCompliancePolicyState `
    -AccessToken $AccessToken `
    -DeviceId $DeviceId

Retrieves compliance policy evaluation states for the specified
Intune-managed device.

.EXAMPLE
Get-IntuneDeviceCompliancePolicyState -AccessToken $AccessToken -DeviceId $DeviceId -Verbose

Retrieves compliance policy states and outputs verbose paging information.

.NOTES
- Uses Microsoft Graph v1.0 `/deviceCompliancePolicyStates` endpoint
- Returns device-scoped compliance evaluation results
- Automatically follows @odata.nextLink for paging
- Nested objects are stored as JSON strings
- Intended for use as a data source for Juriba compliance reporting
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
        [Parameter(Mandatory = $false)]
        [string]$Uri 
    )    

    begin {
        $dtResults = New-Object System.Data.DataTable
        $pageCount = 0
        if ([string]::IsNullOrWhiteSpace($Uri)) {
            $Uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$DeviceId/deviceCompliancePolicyStates"
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