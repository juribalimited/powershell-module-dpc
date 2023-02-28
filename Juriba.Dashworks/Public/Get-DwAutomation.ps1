Function Get-DwAutomation {
    <#
    .SYNOPSIS

    Returns existing automations.

    .DESCRIPTION

    Returns existing automations using Dashworks API v1.

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
        $uri = "{0}/apiv1/admin/automations" -f $Instance
        $headers = @{'x-api-key' = $APIKey }
    
        $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType 'application/json'
    
        return (($result.content | ConvertFrom-Json ).results)

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}