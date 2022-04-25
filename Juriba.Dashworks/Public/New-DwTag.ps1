Function New-DwTag {
    <#
    .SYNOPSIS

    Creates a new list tag.

    .DESCRIPTION

    Creates a new list tag using Dashworks API v1.
    
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Instance,
        [Parameter(Mandatory = $true)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    $body = @{
        tag = $Name
    } | ConvertTo-Json

    $uri = "{0}/apiv1/tags" -f $Instance
    $headers = @{ 'x-api-key' = $APIKey }

    try {
        if ($PSCmdlet.ShouldProcess($Name)) {
            Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $body -ContentType 'application/json'
        }
    }
    catch {
            Write-Error $_
    }
}
