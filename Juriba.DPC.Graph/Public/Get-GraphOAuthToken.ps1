function Get-GraphOAuthToken {
<#
.SYNOPSIS
Obtains a Microsoft Graph OAuth 2.0 access token using the client credentials flow.

.DESCRIPTION
Requests an OAuth 2.0 access token from Microsoft Entra ID using an application
(client) ID and client secret. This token can be used to authenticate requests
to Microsoft Graph in non-interactive scenarios such as service integrations
and automated imports.

This function uses the Azure AD v1 OAuth token endpoint and returns the raw
token response from Entra ID.

.PARAMETER TenantId
The Microsoft Entra ID tenant ID (GUID).

.PARAMETER ClientId
The application (client) ID of the Entra ID app registration.

.PARAMETER ClientSecret
The client secret associated with the Entra ID application.

.PARAMETER Scope
Optional OAuth scope. Intended for use with alternative endpoints.
If not specified, the Microsoft Graph resource endpoint is used.

.OUTPUTS
PSCustomObject

Returns the OAuth token response, which includes:
- access_token
- token_type
- expires_in

.EXAMPLE
$tokenResponse = Get-GraphOAuthToken `
    -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -ClientId "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy" `
    -ClientSecret "********"

$accessToken = $tokenResponse.access_token

Retrieves a Microsoft Graph access token using client credentials.

.EXAMPLE
$token = (Get-GraphOAuthToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $Secret).access_token
Get-EntraIdUser -AccessToken $token

Retrieves an access token and immediately uses it for a Graph query.

.NOTES
- Uses the OAuth 2.0 client credentials flow
- Token endpoint: https://login.microsoftonline.com/{tenant}/oauth2/token
- Requires Microsoft Graph application permissions granted via admin consent
- Suitable for automation and service-to-service authentication
#>
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$ClientId,

        [Parameter(Mandatory = $true)]
        [string]$ClientSecret,

        [Parameter(Mandatory = $false)]
        [string]$Scope
    )

    # Construct OAuth URI
    $oauthUri = "https://login.microsoftonline.com/$TenantId/oauth2/token"

    # Build request body
    $oauthBody = @{
        grant_type    = 'client_credentials'
        client_id     = $ClientId
        client_secret = $ClientSecret
    }

    if ($Scope) {
        $oauthBody['scope'] = $Scope
    }
    else {
        $oauthBody['resource'] = 'https://graph.microsoft.com'
    }

    # Headers
    $oauthHeaders = @{
        'Content-Type' = 'application/x-www-form-urlencoded'
    }

    try {
        # Invoke REST API
        $response = Invoke-RestMethod -Method 'POST' -Uri $oauthUri -Body $oauthBody -Headers $oauthHeaders -ErrorAction Stop

        if ($null -eq $response.access_token) {
            throw "Access token not found in response."
        }

        return $response
    }
    catch {
        Write-Error "Failed to retrieve access token: $_"
        return $null
    }
}