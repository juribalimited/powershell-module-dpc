function Get-JuribaEvergreenSelfServicePage {
    <#
    .SYNOPSIS
    Gets pages for existing self services.
    .DESCRIPTION
    Gets pages for existing self services using Dashworks API v1.
    .PARAMETER Instance
    Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app
    .PARAMETER APIKey
    Optional. API key to be provided if not authenticating using Connect-Juriba.
    .PARAMETER serviceId
    serviceId for the self service being edited.
    .OUTPUTS
    Self service page objects
    pageId, serviceId, objectTypeId, order, name, displayName, showInSelfService, listId, userListId, isPageInteractive, pageStatusId, pageStatusName, isPageInvalid, nextPageId, previousPageId, components
    .EXAMPLE
    PS> Get-JuribaEvergreenSelfServicePage -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -serviceId 15
    #>							  
    [alias("Get-DwEvergreenSelfServicePage")]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$serviceId
    )

    $uri = "{0}/apiv1/admin/selfservices/{1}/pages" -f $Instance, $serviceID
    $headers = @{
        'x-api-key' = $APIKey
        'cache-control' = 'no-cache'
    }
	
    try {
        $result = Invoke-WebRequest -Uri $Uri -Method GET -Headers $headers -ContentType "application/json"
        return ($result.content | ConvertFrom-Json)
    }
	Catch {
		Write-Error $_
	}
}