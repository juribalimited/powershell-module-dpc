function Update-ServiceNowToken {
    <#
    .Synopsis
    Refreshes a ServiceNow OAuth token using its refresh token.

    .Description
    Takes the token object returned from Get-ServiceNowToken (AuthType OAuth) and requests a new access
    token from /oauth_token.do using the refresh_token grant. Returns a new token object with an updated
    Authorization header and expiry.

    .Parameter OAuthToken
    The token object returned from Get-ServiceNowToken with AuthType OAuth.

    .Outputs
    Output type [PSCustomObject]
    A refreshed token object with ServerURL, AuthHeader and expiry properties.

    .Example
    $OAuthToken = Update-ServiceNowToken -OAuthToken $OAuthToken
    #>
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    [OutputType([System.Object[]])]
    param (
        [Parameter(Mandatory=$true)][PSObject] $OAuthToken
    )

    $Reply = New-Object -TypeName PSCustomObject

    $body = [System.Text.Encoding]::UTF8.GetBytes('grant_type=refresh_token&client_id='+[uri]::EscapeDataString($OAuthToken.ClientID)+'&client_secret='+[uri]::EscapeDataString($OAuthToken.ClientSecret)+'&refresh_token='+[uri]::EscapeDataString($OAuthToken.Refresh_Token))
    try{
        if ($PSCmdlet.ShouldProcess(
                ("Updating Token"),
                ("This will update the ServiceNow Token, continue?"),
                "Confirm ServiceNow Token Update"
                )
        ) {
            [PSCustomObject]$Reply = Invoke-RestMethod -Uri "$($OAuthToken.ServerURL)/oauth_token.do" -Body $Body -ContentType 'application/x-www-form-urlencoded' -Method Post
        }

        if ($Reply.GetType().Name -eq 'string')
        {
            write-error 'Auth request returned a string. Please check host.'
            $Reply = $null
        }else{
            #Add the properties to the OAuth return object so that they can be checked later.
            $Reply | Add-Member -NotePropertyName expires -NotePropertyValue (get-date).AddSeconds($Reply.expires_in)
            $Reply | Add-Member -NotePropertyName Clientid -NotePropertyValue $OAuthToken.Clientid
            $Reply | Add-Member -NotePropertyName ClientSecret -NotePropertyValue $OAuthToken.ClientSecret
            $Reply | Add-Member -NotePropertyName ServerURL -NotePropertyValue $OAuthToken.ServerURL
            $Reply | Add-Member -NotePropertyName AuthHeader -NotePropertyValue "Bearer $($Reply.access_token)"
            $Reply | Add-Member -NotePropertyName refresh_token_expires -NotePropertyValue (get-date).AddDays(100)
        }
    }
    catch{
        write-error "Auth Token Refresh Failed - $($_.exception)"
    }
    return ,$Reply
}
