#requires -Version 7
function Start-JuribaETLJob {
    <#
        .SYNOPSIS
        Run an ETL job.

        .DESCRIPTION
        Trigger a specified ETL job using Job ID.

        .PARAMETER Instance

        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER JobId

        Required. The id for the ETL job.

        .EXAMPLE

        PS> Start-JuribaETLJob -JobId 1 -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$true,
        ParameterSetName="JobId")]
        [string]$JobId
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance -and $JobId) {
        $uri = "{0}/apiv2/etl-jobs/{1}" -f $Instance, $JobId
        $headers = @{'x-api-key' = $APIKey}
        try {
            $result = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers
            return $result
        }
        catch {
            Write-Error $_
        }
    
    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}