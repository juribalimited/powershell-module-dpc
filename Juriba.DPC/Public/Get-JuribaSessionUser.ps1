Function Get-JuribaSessionUser {
        <#
    .SYNOPSIS

    Returns information about the authenticated user.

    .DESCRIPTION

    Returns information about the authenticated user using Dashworks API v1.

    .PARAMETER Instance

    Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

    .PARAMETER APIKey

    Optional. API key to be provided if not authenticating using Connect-Juriba.

    #>
    [alias("Get-DwSessionUser")]
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