function Get-IntuneDevice {
<#
.SYNOPSIS
Retrieves Intune-managed devices via Microsoft Graph.

.DESCRIPTION
Queries the Microsoft Graph `/deviceManagement/managedDevices` v1.0 endpoint
to retrieve all devices managed by Microsoft Intune that are accessible to
the supplied access token.

The function automatically handles Graph API pagination and returns the
complete result set as a System.Data.DataTable. Properties returned by
Microsoft Graph are dynamically converted into DataTable columns.

Any nested or complex properties are flattened and stored as compressed
JSON strings to preserve the source data for downstream processing, such
as importing device inventory data into Juriba.

.PARAMETER AccessToken
A valid OAuth 2.0 bearer token for Microsoft Graph with permission to
read Intune managed device data.

.PARAMETER Uri
Optional Microsoft Graph endpoint URI.

Defaults to:
`https://graph.microsoft.com/v1.0/deviceManagement/managedDevices`

This parameter is primarily intended for pagination or advanced scenarios.

.OUTPUTS
System.Data.DataTable

A DataTable where each row represents a Microsoft Intune managed device.
Columns are created dynamically based on the properties returned by
Microsoft Graph.

.EXAMPLE
$dtDevices = Get-IntuneDevice -AccessToken $AccessToken

Retrieves all Intune-managed devices accessible to the provided token.

.EXAMPLE
Get-IntuneDevice -AccessToken $AccessToken -Verbose

Retrieves managed devices and outputs verbose paging information.

.NOTES
- Uses Microsoft Graph v1.0 `/deviceManagement/managedDevices` endpoint
- Automatically follows @odata.nextLink for paging
- Nested objects are stored as JSON strings
- Intended for use as a data source for Juriba device inventory imports
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
            $Uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
        }
    }

    process {
        do {
            if ([string]::IsNullOrWhiteSpace($Uri)) { break }
            $pageCount++
            Write-Verbose "Fetching page $pageCount from Graph API: $uri"

            try {
                $devices = Invoke-RestMethod -Headers @{ Authorization = "Bearer $AccessToken" } -Uri $uri -Method Get
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
                $uri = $devices.'@odata.nextLink'
            } else {
                $uri = $null
            }
        } while ($null -ne $uri)
    }

    end {
        Write-Verbose "Returning DataTable with $($dtResults.Rows.Count) rows across $pageCount pages."
        return $dtResults
    }
}