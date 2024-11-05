function Get-ServiceNowToken {
    [OutputType([System.Management.Automation.PSCustomObject[]])]
    param (
            [Parameter(Mandatory=$true)][ValidateSet("OAuth", "Basic")][string] $AuthType,
            [Parameter(Mandatory=$true)][string] $Server,
            [Parameter(Mandatory=$true)][pscredential] $Credential,
            [Parameter(Mandatory=$False)][string] $ClientID,
            [Parameter(Mandatory=$False)][string] $ClientSecret
    )

    $Reply = New-Object -TypeName PSCustomObject

    if ($AuthType -eq 'Basic')
    {
        $pair = "{0}:{1}" -f $Credential.UserName, $Credential.GetNetworkCredential().password
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $basicAuthValue = "Basic $base64"

        #Add the properties to the OAuth return object so that they can be checked later.
        $Reply | Add-Member -NotePropertyName ServerURL -NotePropertyValue $Server
        $Reply | Add-Member -NotePropertyName AuthHeader -NotePropertyValue $basicAuthValue
        $Reply | Add-Member -NotePropertyName expires -NotePropertyValue (get-date).AddDays(100)
    }else{
        #Token doesn't exist or cannot be refreshed: Get a new token and store the values
        $body = [System.Text.Encoding]::UTF8.GetBytes('grant_type=password&username='+[uri]::EscapeDataString($($Credential.UserName))+'&password='+[uri]::EscapeDataString($($Credential.GetNetworkCredential().password))+'&client_id='+[uri]::EscapeDataString($ClientID)+'&client_secret='+[uri]::EscapeDataString($ClientSecret))

        $Reply = Invoke-RESTMethod -Method 'Post' -URI "$($Server)/oauth_token.do" -body $Body -ContentType "application/x-www-form-urlencoded"

        if ($Reply.GetType().Name -eq 'string')
        {
            write-error 'Auth request returned a string. Please check host.'
            $Reply = $null
        }else{
            #Add the properties to the OAuth return object so that they can be checked later.
            $Reply | Add-Member -NotePropertyName expires -NotePropertyValue (get-date).AddSeconds($Reply.expires_in)
            $Reply | Add-Member -NotePropertyName Clientid -NotePropertyValue $Clientid
            $Reply | Add-Member -NotePropertyName ClientSecret -NotePropertyValue $ClientSecret
            $Reply | Add-Member -NotePropertyName ServerURL -NotePropertyValue $Server
            $Reply | Add-Member -NotePropertyName AuthHeader -NotePropertyValue "Bearer $($Reply.access_token)"
            $Reply | Add-Member -NotePropertyName refresh_token_expires -NotePropertyValue (get-date).AddDays(100)
        }
        Write-Debug "New Auth Token Obtained - expires $($Reply.Expires)"
    }
    return $Reply
}