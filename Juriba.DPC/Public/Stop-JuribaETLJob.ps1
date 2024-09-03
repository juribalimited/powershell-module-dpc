#requires -Version 7
function Stop-JuribaETLJob {
    <#
        .SYNOPSIS
        Stop an ETL job.

        .DESCRIPTION
        Stop a specified ETL job using Job ID.

        .PARAMETER Instance

        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER JobId

        Required. The id for the ETL job.

        .EXAMPLE

        PS> Stop-JuribaETLJob -JobId 1 -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
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
            $job = Get-JuribaETLJob -Instance $Instance -APIKey $APIKey -JobId $JobId
            if ($PSCmdlet.ShouldProcess(
                ("Stopping Job {0}" -f $job.name),
                ("This action will stop Job {0} in state {1}, continue?" -f $job.name, $job.status),
                "Confirm Job cancellation"
                )
            ) {
                $result = Invoke-RestMethod -Uri $uri -Method DELETE -Headers $headers
                return $result
            }
        }
        catch {
            Write-Error $_
        }
    
    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}