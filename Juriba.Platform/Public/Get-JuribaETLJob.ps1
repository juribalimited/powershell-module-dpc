#requires -Version 7
function Get-JuribaETLJob {
    <#
        .SYNOPSIS
        Gets ETL jobs 

        .DESCRIPTION
        Gets one or more ETL jobs.
        Use JobId to get a specific ETL or omit for all jobs.

        .PARAMETER Instance

        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER JobId

        Optional. The id for the ETL job. Omit to get all jobs.

        .PARAMETER Name

        Optional. Name of the ETL Job to find. Can only be used when JobId is not specified.

        .EXAMPLE

        PS> Get-JuribaETLJob -JobId 1 -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"
                
        .EXAMPLE

        PS> Get-JuribaETLJob -Name "Dashworks ETL (Transform Only)" -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>
    [CmdletBinding(DefaultParameterSetName="Name")]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$false,
        ParameterSetName="JobId")]
        [string]$JobId,
        [parameter(Mandatory=$false,
        ParameterSetName="Name")]
        [string]$Name
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $uri = "{0}/apiv2/etl-jobs" -f $Instance

        if ($JobId) {$uri += "/{0}" -f $JobId}
        if ($Name) {
            $uri += "?filter="
            $uri += [System.Web.HttpUtility]::UrlEncode("eq(name,'{0}')" -f $Name)
        }
        
        $headers = @{'x-api-key' = $APIKey}
        try {
            $result = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
            return $result
        }
        catch {
            Write-Error $_
        }
    
    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}