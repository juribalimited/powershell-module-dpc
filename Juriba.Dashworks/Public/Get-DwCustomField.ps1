function Get-DwCustomField {
    <#
    .SYNOPSIS

    Gets custom fields.

    .DESCRIPTION

    Gets custom fields using the Dashworks API v1.

    .PARAMETER Instance

    Dashworks instance. For example, https://myinstance.dashworks.app:8443

    .PARAMETER APIKey

    Dashworks API Key.

    .OUTPUTS

    None.

    .EXAMPLE

    PS> Get-DwCustomField -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey
    )

    $uri = "{0}/apiv1/custom-fields" -f $Instance
    $headers = @{'x-api-key' = $APIKey }

    try {
        $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType 'application/json'
        if ($result.StatusCode -eq 200) {
            return ($result.Content | ConvertFrom-Json)
        }
        else {
            Write-Error $_
        }
    }
    catch {
            Write-Error $_
    }
}
