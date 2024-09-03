function Get-JuribaProjectReadiness {
    [alias("Get-DwProjectReadiness")]
    <#
        .SYNOPSIS
        Gets the Project Readiness.
        .DESCRIPTION
        Gets the Project Readiness using Dashworks API v1.
        .PARAMETER Instance
        Dashworks instance. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Dashworks API Key.
        .PARAMETER ProjectID
        ProjectID to query.
        .OUTPUTS
        Readiness objects
        ragStatusId, ragStatus, tooltip, foreColorHtml, backColorHtml, displayOrder
        .EXAMPLE
        PS> Get-JuribaProjectReadiness @dwparams -ProjectID 1
    #>
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