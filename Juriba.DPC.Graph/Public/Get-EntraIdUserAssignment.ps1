function Get-EntraIdUserAssignment {
<#
.SYNOPSIS
Retrieves application role assignments for an Entra ID user.

.DESCRIPTION
Queries the Microsoft Graph `/users/{id}/appRoleAssignments` v1.0 endpoint
to retrieve application role assignments for a specified Entra ID user.

These assignments represent enterprise applications or service principals
to which the user has been granted roles. The function returns the raw
Microsoft Graph response object and does not perform any further
transformation.

.PARAMETER AccessToken
A valid OAuth 2.0 bearer token for Microsoft Graph with permission to
read Entra ID user app role assignments.

.PARAMETER UserId
The object ID (GUID) of the Entra ID user whose application role
assignments should be retrieved.

.PARAMETER Uri
Optional Microsoft Graph endpoint URI.

Defaults to:
`https://graph.microsoft.com/v1.0/users/{UserId}/appRoleAssignments`

This parameter is intended for advanced or testing scenarios.

.OUTPUTS
PSCustomObject

Returns the raw Microsoft Graph response containing one or more
user app role assignment objects.

.EXAMPLE
$response = Get-EntraIdUserAssignment `
    -AccessToken $AccessToken `
    -UserId $UserId

Retrieves all application role assignments for the specified user.

.EXAMPLE
Get-EntraIdUserAssignment -AccessToken $AccessToken -UserId $UserId | Format-List

Retrieves user app role assignments and formats the output for inspection.

.NOTES
- Uses Microsoft Graph v1.0 `/users/{id}/appRoleAssignments` endpoint
- Returns raw Graph response; no paging or transformation is applied
- Intended for Entra ID authorization and application assignment analysis
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
        $uri = "https://graph.microsoft.com/v1.0/users/$UserId/appRoleAssignments"
    }    

    Write-Verbose "Fetching user app role assignments from Graph API: $Uri"

    try {
        $response = Invoke-RestMethod -Headers @{ Authorization = "Bearer $AccessToken" } -Uri $uri -Method Get
    }
    catch {
        throw "Failed to retrieve data from Graph API: $_"
    }
        
    return $response
}