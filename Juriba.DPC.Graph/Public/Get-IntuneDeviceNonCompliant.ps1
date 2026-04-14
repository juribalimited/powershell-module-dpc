function Get-IntuneDeviceNonCompliant {
<#
.SYNOPSIS
Retrieves non-compliant Intune-managed devices via Microsoft Graph.

.DESCRIPTION
Queries the Microsoft Graph `/deviceManagement/managedDevices` v1.0 endpoint
to retrieve all Intune-managed devices whose compliance state is reported
as non-compliant.

The function applies a `complianceState eq 'noncompliant'` filter and
automatically handles Graph API pagination. Results are returned as a
System.Data.DataTable with dynamically generated columns.

Any nested or complex properties are flattened and stored as compressed
JSON strings to preserve the original data structure for downstream
processing, such as importing non-compliance data into Juriba.

.PARAMETER AccessToken
A valid OAuth 2.0 bearer token for Microsoft Graph with permission to
read Intune managed device compliance data.

.PARAMETER Uri
Optional Microsoft Graph endpoint URI.

Defaults to:
`https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$filter=complianceState eq 'noncompliant'`

This parameter is intended for advanced or paging scenarios.

.OUTPUTS
System.Data.DataTable

A DataTable where each row represents an Intune-managed device that is
currently reported as non-compliant. Columns are created dynamically
based on the properties returned by Microsoft Graph.

.EXAMPLE
$dtNonCompliant = Get-IntuneDeviceNonCompliant -AccessToken $AccessToken

Retrieves all non-compliant Intune-managed devices accessible to the token.

.EXAMPLE
Get-IntuneDeviceNonCompliant -AccessToken $AccessToken -Verbose

Retrieves non-compliant devices and outputs verbose paging information.

.NOTES
- Uses Microsoft Graph v1.0 `/deviceManagement/managedDevices` endpoint
- Applies `complianceState eq 'noncompliant'` filter by default
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
        [Parameter(Mandatory = $false)]
        [string]$Uri  
    )    

    begin {
        $dtResults = New-Object System.Data.DataTable
        $pageCount = 0
        if ([string]::IsNullOrWhiteSpace($Uri)) {
            $Uri = 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$filter=complianceState eq ''noncompliant'''
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