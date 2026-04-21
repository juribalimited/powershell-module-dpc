function Get-EntraIdUserAttribute {
<#
.SYNOPSIS
Retrieves directory attributes for a specific Entra ID user.

.DESCRIPTION
Queries the Microsoft Graph `/beta/users` endpoint to retrieve the full
directory object for a specified Entra ID user.

The function returns a single user object containing all attributes
exposed by Microsoft Graph at the time of the request. No transformation
or flattening is applied to the returned data.

This cmdlet is intended for scenarios where an individual user’s raw
Entra ID attributes are required for inspection or downstream processing.

.PARAMETER AccessToken
A valid OAuth 2.0 bearer token for Microsoft Graph with permission to
read Entra ID user data.

.PARAMETER UserId
The object ID (GUID) of the Entra ID user whose attributes should be retrieved.

.PARAMETER Uri
Optional Microsoft Graph endpoint URI.

Defaults to:
`https://graph.microsoft.com/beta/users?$filter=id eq '{UserId}'`

This parameter is intended for advanced or testing scenarios.

.OUTPUTS
PSCustomObject

Returns a single Microsoft Graph user object containing directory
attributes for the specified user.

.EXAMPLE
$user = Get-EntraIdUserAttribute `
    -AccessToken $AccessToken `
    -UserId $UserId

Retrieves all available directory attributes for the specified user.

.EXAMPLE
Get-EntraIdUserAttribute -AccessToken $AccessToken -UserId $UserId | Format-List

Retrieves the user object and displays all attributes in list format.

.NOTES
- Uses Microsoft Graph **beta** `/users` endpoint
- Returns a single user object; no paging is performed
- Attribute availability may change between Graph beta versions
- Intended for Entra ID attribute discovery or enrichment scenarios
#>
    [OutputType([pscustomobject])]
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

    if (-not $Uri) {
        $uri = "https://graph.microsoft.com/beta/users?`$filter=id eq '$UserId'"
    }    

    Write-Verbose "Fetching user from Graph API: $uri"

    try {
        $response = Invoke-RestMethod -Headers @{ Authorization = "Bearer $AccessToken" } -Uri $uri -Method Get
    }
    catch {
        throw "Failed to retrieve data from Graph API: $_"
    }

    if (-not $response.value -or $response.value.Count -eq 0) {
    Write-Verbose "No user found for ID $UserId"
    return $null
    }
    
    return $response.value[0]
}