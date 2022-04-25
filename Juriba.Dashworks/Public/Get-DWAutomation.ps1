Function Get-DwAutomation {
    <#
    .SYNOPSIS

    Returns existing automations.

    .DESCRIPTION

    Returns existing automations using Dashworks API v1.

    #>

    param(
        [Parameter(Mandatory = $true)]
        [string]$Instance,
        [Parameter(Mandatory = $true)]
        [string]$APIKey
    )
    
    $uri = "{0}/apiv1/admin/automations" -f $Instance
    $headers = @{'x-api-key' = $APIKey }

    $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType 'application/json'

    return (($result.content | ConvertFrom-Json ).results)

}