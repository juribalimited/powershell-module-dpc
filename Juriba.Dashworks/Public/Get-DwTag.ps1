Function Get-DwTag {
    <#
    .SYNOPSIS

    Returns existing list tags.

    .DESCRIPTION

    Returns existing list tags using Dashworks API v1.

    #>

    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $uri = "{0}/apiv1/tags" -f $Instance
        $headers = @{ 'x-api-key' = $APIKey }
    
        try {
            $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType 'application/json'
            return ( $result.Content | ConvertFrom-Json )
        }
        catch {
                Write-Error $_
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Dw before proceeding."
    }
}
