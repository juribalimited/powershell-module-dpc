function Get-JuribaProjectReadiness {
    <#
        .SYNOPSIS
        Gets the Project Readiness.
        .DESCRIPTION
        Gets the Project Readiness using Dashworks API v1.
        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ProjectID
        ProjectID to query.
        .OUTPUTS
        Readiness objects
        ragStatusId, ragStatus, tooltip, foreColorHtml, backColorHtml, displayOrder
        .EXAMPLE
        PS> Get-JuribaProjectReadiness -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -ProjectID 1
    #>
    [alias("Get-DwProjectReadiness")]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$ProjectID
    )
    
    $uri = ("{0}/apiv1/admin/project/{1}/readiness/projectReadinessList" -f $Instance, $ProjectID) + '?$lang=en-US'
    $headers = @{'x-api-key' = $APIKey }
    
    try {
        $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers

        if ($result.StatusCode -eq 200)
        {
            $resulttable = $result.content | ConvertFrom-Json
            return $resulttable.results.readiness
        }
    }
    catch {
        Write-Error $_
    }
}