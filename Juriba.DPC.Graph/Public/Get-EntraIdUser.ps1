function Get-EntraIdUser {
<#
.SYNOPSIS
Retrieves users from Microsoft Entra ID via Microsoft Graph.

.DESCRIPTION
Queries the Microsoft Graph `/users` v1.0 endpoint and retrieves all
Entra ID user objects available to the supplied access token.

The function automatically handles Graph API pagination and returns
the full result set as a System.Data.DataTable. Properties returned by
Graph are dynamically converted into DataTable columns.

Any nested or complex properties are flattened and stored as compressed
JSON strings to preserve the source data for downstream processing,
such as importing into Juriba.

.PARAMETER AccessToken
A valid OAuth 2.0 bearer token for Microsoft Graph with permission
to read Entra ID user objects.

.PARAMETER Uri
Optional Microsoft Graph endpoint URI.
Defaults to `https://graph.microsoft.com/v1.0/users`.

This parameter is primarily intended for pagination or advanced scenarios.

.OUTPUTS
System.Data.DataTable

A DataTable where each row represents an Entra ID user object returned
by Microsoft Graph. Columns are created dynamically based on the properties
returned by the API.

.EXAMPLE
$dt = Get-EntraIdUser -AccessToken $AccessToken

Retrieves all Entra ID users accessible to the provided access token.

.EXAMPLE
$dt = Get-EntraIdUser -AccessToken $AccessToken -Verbose

Retrieves all users and outputs verbose information about Graph API paging.

.NOTES
- Uses Microsoft Graph v1.0 `/users` endpoint
- Automatically follows @odata.nextLink for paging
- Nested objects are stored as JSON strings
- Intended for use as a data source for Juriba imports
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
            $Uri = "https://graph.microsoft.com/v1.0/users"
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