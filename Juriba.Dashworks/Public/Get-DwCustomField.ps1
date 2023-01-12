function Get-DwCustomField {
    <#
    .SYNOPSIS

    Gets custom fields.

    .DESCRIPTION

    Gets custom fields using the Dashworks API v1.

    .PARAMETER Instance

    Optional. Dashworks instance to be provided if not authenticating using Connect-Dw. For example, https://myinstance.dashworks.app:8443

    .PARAMETER APIKey

    Optional. API key to be provided if not authenticating using Connect-Dw.

    .OUTPUTS

    None.

    .EXAMPLE

    PS> Get-DwCustomField -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>

    [CmdletBinding()]
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

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Dw before proceeding."
    }
}
