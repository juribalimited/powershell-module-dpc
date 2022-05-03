Function Get-DwSessionUser {
        <#
    .SYNOPSIS

    Returns information about the authenticated user.

    .DESCRIPTION

    Returns information about the authenticated user using Dashworks API v1.

    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey
    )

        $contentType = "application/json"
        $headers = @{ 'X-API-KEY' = $ApiKey }
        $uri = "{0}/apiv1/security/userprofile" -f $Instance

        $result = Invoke-WebRequest -Uri $uri -Headers $headers -Method GET -ContentType $contentType

        return ( $result.content | ConvertFrom-Json )

    }