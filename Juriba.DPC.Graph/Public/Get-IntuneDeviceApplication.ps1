function Get-IntuneDeviceApplication {
<#
.SYNOPSIS
Retrieves Intune mobile application intent and state data for a user-device pair.

.DESCRIPTION
Queries the Microsoft Graph **beta** `/users/{id}/mobileAppIntentAndStates/{deviceId}`
endpoint to retrieve Intune mobile application intent and installation state
information for a specific Entra ID user and managed device combination.

The returned data reflects application assignment intent (required, available)
and installation state as evaluated by Intune for the specified device.
The function returns the raw Microsoft Graph response object without
performing transformation or pagination.

.PARAMETER AccessToken
A valid OAuth 2.0 bearer token for Microsoft Graph with permission to
read Intune mobile application state data.

.PARAMETER UserId
The object ID (GUID) of the Entra ID user associated with the managed device.

.PARAMETER DeviceId
The Intune managed device ID for which application intent and state
information should be retrieved.

.PARAMETER Uri
Optional Microsoft Graph endpoint URI.

Defaults to:
`https://graph.microsoft.com/beta/users('{UserId}')/mobileAppIntentAndStates('{DeviceId}')`

This parameter is intended for advanced or testing scenarios.

.OUTPUTS
PSCustomObject

Returns the raw Microsoft Graph response containing Intune mobile
application intent and state information for the specified user-device pair.

.EXAMPLE
$response = Get-IntuneDeviceApplication `
    -AccessToken $AccessToken `
    -UserId $UserId `
    -DeviceId $DeviceId

Retrieves Intune application intent and installation state for a specific
user and managed device.

.EXAMPLE
Get-IntuneDeviceApplication -AccessToken $AccessToken -UserId $UserId -DeviceId $DeviceId |
    Format-List

Retrieves application state data and formats the output for inspection.

.NOTES
- Uses Microsoft Graph **beta** endpoint
- Returns raw Graph response; no transformation or pagination is applied
- Data represents Intune application intent and evaluation state
- Schema and availability may change between Graph beta versions
- Intended for Intune application state analysis and troubleshooting
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
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceId,
        [Parameter(Mandatory = $false)]
        [string]$Uri     
    )   

    if (-not $Uri) {
        $uri = 'https://graph.microsoft.com/beta/users(''' + $UserId + ''')/mobileAppIntentAndStates(''' + $DeviceId +''')'
    }    

    Write-Verbose "Fetching Intune application intent and state from Graph API: $Uri"

    try {
        $response = Invoke-RestMethod -Headers @{ Authorization = "Bearer $AccessToken" } -Uri $uri -Method Get
    }
    catch {
        throw "Failed to retrieve data from Graph API: $_"
    }

    if (-not $response.userId -or -not $response.managedDeviceIdentifier) {
    Write-Verbose "No user found for ID $UserId or no device found for ID $DeviceId"
    return $null
    }
    
    return $response
}