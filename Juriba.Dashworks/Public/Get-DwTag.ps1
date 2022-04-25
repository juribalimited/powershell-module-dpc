Function Get-DwTag {
    <#
    .SYNOPSIS

    Returns existing list tags.

    .DESCRIPTION

    Returns existing list tags using Dashworks API v1.

    #>

    param(
        [Parameter(Mandatory = $true)]
        [string]$Instance,
        [Parameter(Mandatory = $true)]
        [string]$APIKey
    )

    $uri = "{0}/apiv1/tags" -f $Instance
    $headers = @{ 'x-api-key' = $APIKey }

    try {
        $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType 'application/json'
        return ( $result.Content | ConvertFrom-Json )
    }
    catch {
            Write-Error $_
    }
}
