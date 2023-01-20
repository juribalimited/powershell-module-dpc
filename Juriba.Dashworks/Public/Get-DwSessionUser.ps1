Function Get-DwSessionUser {
        <#
    .SYNOPSIS

    Returns information about the authenticated user.

    .DESCRIPTION

    Returns information about the authenticated user using Dashworks API v1.

    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $contentType = "application/json"
        $headers = @{ 'X-API-KEY' = $ApiKey }
        $uri = "{0}/apiv1/security/userprofile" -f $Instance

        $result = Invoke-WebRequest -Uri $uri -Headers $headers -Method GET -ContentType $contentType

        return ( $result.content | ConvertFrom-Json )

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}