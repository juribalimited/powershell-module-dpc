function Get-EntraIdUserGroupMember {
<#
.SYNOPSIS
Retrieves security group memberships for an Entra ID user.

.DESCRIPTION
Queries the Microsoft Graph `/users/{id}/transitiveMemberOf/microsoft.graph.group`
v1.0 endpoint to retrieve all security-enabled groups of which the specified
Entra ID user is a member.

Both direct and transitive (nested) group memberships are included.
The function automatically handles Graph API pagination and returns
the full result set as a System.Data.DataTable.

Any nested or complex properties returned by Microsoft Graph are flattened
and stored as compressed JSON strings for downstream processing.

.PARAMETER AccessToken
A valid OAuth 2.0 bearer token for Microsoft Graph with permission to
read Entra ID group membership data.

.PARAMETER UserId
The object ID (GUID) of the Entra ID user whose group memberships
should be retrieved.

.PARAMETER Uri
Optional Microsoft Graph endpoint URI.

Defaults to:
`https://graph.microsoft.com/v1.0/users/{UserId}/transitiveMemberOf/microsoft.graph.group?$filter=securityEnabled eq true&$count=true`

This parameter is intended for advanced or paging scenarios.

.OUTPUTS
System.Data.DataTable

A DataTable where each row represents a security-enabled Entra ID group
to which the user belongs, including transitive (nested) memberships.
Columns are created dynamically based on the properties returned by
Microsoft Graph.

.EXAMPLE
$dt = Get-EntraIdUserGroupMember -AccessToken $AccessToken -UserId $UserId

Retrieves all security group memberships for the specified Entra ID user.

.EXAMPLE
$dt = Get-EntraIdUserGroupMember -AccessToken $AccessToken -UserId $UserId -Verbose

Retrieves group memberships and outputs verbose paging information.

.NOTES
- Uses Microsoft Graph v1.0 `transitiveMemberOf` endpoint
- Applies `securityEnabled eq true` filter by default
- Includes both direct and nested group memberships
- Requires `ConsistencyLevel: eventual` header for `$count` support
- Nested objects are stored as JSON strings
- Intended for use as a data source for Juriba user-group membership imports
#>
    [OutputType([System.Data.DataTable])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$UserId,
        [Parameter(Mandatory = $false)]
        [string]$Uri
    )    

    begin {
        $dtResults = New-Object System.Data.DataTable
        $pageCount = 0
        if ([string]::IsNullOrWhiteSpace($Uri)) {
            $Uri = "https://graph.microsoft.com/v1.0/users/$UserId/transitiveMemberOf/microsoft.graph.group?`$filter=securityEnabled eq true&`$count=true"
        }
    }

    process {
        do {
            if ([string]::IsNullOrWhiteSpace($Uri)) { break }
            $pageCount++
            Write-Verbose "Fetching page $pageCount from Graph API: $uri"

            try {
                $headers = @{
                    Authorization = "Bearer $AccessToken"
                    ConsistencyLevel = "eventual"
                }
                $response = Invoke-RestMethod -Headers $headers -Uri $uri -Method Get
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