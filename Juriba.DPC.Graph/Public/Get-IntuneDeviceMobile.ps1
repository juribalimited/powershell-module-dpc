function Get-IntuneDeviceMobile {
<#
.SYNOPSIS
Retrieves Intune-managed mobile devices via Microsoft Graph.

.DESCRIPTION
Queries the Microsoft Graph `/deviceManagement/managedDevices` v1.0 endpoint
to retrieve Intune-managed mobile devices, filtered to devices running
iOS or Android operating systems.

The function automatically handles Graph API pagination and returns the
complete result set as a System.Data.DataTable. Properties returned by
Microsoft Graph are dynamically converted into DataTable columns.

Any nested or complex properties are flattened and stored as compressed
JSON strings for downstream processing, such as importing mobile device
inventory data into Juriba.

.PARAMETER AccessToken
A valid OAuth 2.0 bearer token for Microsoft Graph with permission to
read Intune managed device data.

.PARAMETER Uri
Optional Microsoft Graph endpoint URI.

Defaults to:
`https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$filter=operatingSystem eq 'iOS' or operatingSystem eq 'Android'`

This parameter is primarily intended for paging or advanced scenarios.

.OUTPUTS
System.Data.DataTable

A DataTable where each row represents an Intune-managed mobile device
(iOS or Android). Columns are created dynamically based on the properties
returned by Microsoft Graph.

.EXAMPLE
$dtMobileDevices = Get-IntuneDeviceMobile -AccessToken $AccessToken

Retrieves all Intune-managed iOS and Android devices.

.EXAMPLE
Get-IntuneDeviceMobile -AccessToken $AccessToken -Verbose

Retrieves mobile devices and outputs verbose paging information.

.NOTES
- Uses Microsoft Graph v1.0 `/deviceManagement/managedDevices` endpoint
- Filters devices to iOS and Android operating systems only
- Automatically follows @odata.nextLink for paging
- Nested objects are stored as JSON strings
- Intended for Intune mobile device reporting and Juriba imports
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
            $Uri = 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$filter=operatingSystem eq ''iOS'' or operatingSystem eq ''Android'''
        }
    }

    process {
        do {
            if ([string]::IsNullOrWhiteSpace($Uri)) { break }
            $pageCount++
            Write-Verbose "Fetching page $pageCount from Graph API: $Uri"

            try {
                $response = Invoke-RestMethod -Headers @{ Authorization = "Bearer $AccessToken" } -Uri $Uri -Method Get
            }
            catch {
                Write-Error "Failed to retrieve data from Graph API: $_"
                return
            }

            if (-not $response.Value) { break }

            foreach ($entry in $response.Value) {
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
            if ($response.PSObject.Properties.Name -contains '@odata.nextLink' -and $response.'@odata.nextLink') {
                $Uri = $response.'@odata.nextLink'
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