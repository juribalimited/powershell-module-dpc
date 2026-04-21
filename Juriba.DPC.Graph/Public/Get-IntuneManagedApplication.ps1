function Get-IntuneManagedApplication {
<#
.SYNOPSIS
Retrieves Intune managed application definitions via Microsoft Graph.

.DESCRIPTION
Queries the Microsoft Graph `/deviceAppManagement/mobileApps` v1.0 endpoint
to retrieve all Intune-managed application definitions available in the tenant.

This includes applications such as Win32 apps, iOS and Android apps,
Microsoft Store apps, and other mobile application types managed through
Intune.

The function automatically handles Graph API pagination and returns the
complete result set as a System.Data.DataTable. Properties returned by
Microsoft Graph are dynamically converted into DataTable columns.

Any nested or complex properties are flattened and stored as compressed
JSON strings for downstream processing, such as importing application
catalog data into Juriba.

.PARAMETER AccessToken
A valid OAuth 2.0 bearer token for Microsoft Graph with permission to
read Intune managed application data.

.PARAMETER Uri
Optional Microsoft Graph endpoint URI.

Defaults to:
`https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps`

This parameter is primarily intended for paging or advanced scenarios.

.OUTPUTS
System.Data.DataTable

A DataTable where each row represents an Intune managed application
definition. Columns are created dynamically based on the properties
returned by Microsoft Graph.

.EXAMPLE
$dtApps = Get-IntuneManagedApplication -AccessToken $AccessToken

Retrieves all Intune managed application definitions.

.EXAMPLE
Get-IntuneManagedApplication -AccessToken $AccessToken -Verbose

Retrieves Intune managed applications and outputs verbose paging information.

.NOTES
- Uses Microsoft Graph v1.0 `/deviceAppManagement/mobileApps` endpoint
- Automatically follows @odata.nextLink for paging
- Nested objects are stored as JSON strings
- Intended for Intune application inventory and Juriba imports
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
            $Uri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps"
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