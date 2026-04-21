function Get-IntuneApplication {
<#
.SYNOPSIS
Retrieves application service principals associated with Intune-managed workloads.

.DESCRIPTION
Queries the Microsoft Graph `/servicePrincipals` v1.0 endpoint to retrieve
application service principal objects from Microsoft Entra ID.

Service principals represent enterprise applications and app registrations,
which are commonly used in Intune for application assignment, access control,
and role-based relationships.

The function automatically handles Graph API pagination and returns the full
result set as a System.Data.DataTable. Properties returned by Graph are
dynamically converted into DataTable columns.

Any nested or complex properties are flattened and stored as compressed JSON
strings for downstream processing, such as importing application metadata
into Juriba.

.PARAMETER AccessToken
A valid OAuth 2.0 bearer token for Microsoft Graph with permission to
read service principal objects.

.PARAMETER Uri
Optional Microsoft Graph endpoint URI.

Defaults to:
`https://graph.microsoft.com/v1.0/servicePrincipals`

This parameter is intended for advanced or paging scenarios.

.OUTPUTS
System.Data.DataTable

A DataTable where each row represents a Microsoft Entra ID service principal.
Columns are created dynamically based on the properties returned by
Microsoft Graph.

.EXAMPLE
$dtApplications = Get-IntuneApplication -AccessToken $AccessToken

Retrieves service principal objects that can be correlated with
Intune-managed applications.

.EXAMPLE
Get-IntuneApplication -AccessToken $AccessToken -Verbose

Retrieves service principals and outputs verbose paging information.

.NOTES
- Uses Microsoft Graph v1.0 `/servicePrincipals` endpoint
- Not all returned service principals represent Intune-managed applications
- Intended for correlation with Intune and Entra ID application assignments
- Nested objects are stored as JSON strings
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
            $Uri = "https://graph.microsoft.com/v1.0/servicePrincipals"
        }
    }

    process {
        do {
            $pageCount++
            Write-Verbose "Fetching page $pageCount from Graph API: $uri"

            try {
                $response = Invoke-RestMethod -Headers @{ Authorization = "Bearer $AccessToken" } -Uri $uri -Method Get
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
                $uri = $response.'@odata.nextLink'
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