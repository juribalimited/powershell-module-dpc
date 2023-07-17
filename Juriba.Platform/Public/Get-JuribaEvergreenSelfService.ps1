function Get-JuribaEvergreenSelfService {
    [alias("Get-DwEvergreenSelfService")]
    <#
        .SYNOPSIS
        Gets a list of Evergreen self services.
        .DESCRIPTION
        Gets a list of Evergreen self services using Dashworks API v1.
        .PARAMETER Instance
        Dashworks instance. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Dashworks API Key.
        .OUTPUTS
        Self service objects
        serviceId, name, serviceShortName, enabled, objectType, objectTypeId, creationDate, selfServiceUrl, allowAnonymousUsers, scopeId, scopeName, scopeNameUrlParameter, interactiveComponentCount, scopeNameQueryParameters, scopeLinkAvailable, createdByUser, selfServiceLink, pageIds, completionStatus, objectGuid, scopeIsBroken
        .EXAMPLE
        PS> Get-JuribaEvergreenSelfService @dwparams
    #> 
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey
    )

    $uri = ("{0}/apiv1/admin/selfservices" -f $Instance) + '?$lang=en-US'
    $headers = @{
        'x-api-key' = $APIKey
        'cache-control' = 'no-cache'
    }
	
    try {
        $result = Invoke-WebRequest -Uri $Uri -Method GET -Headers $headers -ContentType "application/json"
        return ($result.content | ConvertFrom-Json).results
    }
	Catch {
		Write-Error $_
	}
}