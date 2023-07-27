function Get-JuribaEvergreenSelfServiceComponent {
    [alias("Get-DwEvergreenSelfServiceComponent")]
    <#
        .SYNOPSIS
        Get self service component.
        .DESCRIPTION
         Get the info of the self service component using Dashworks API v1.
        .PARAMETER Instance
        Dashworks instance. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Dashworks API Key.
        .PARAMETER ServiceId
        ServiceId to get page information from.
        .PARAMETER PageId
        PageId to get components from.
        .OUTPUTS
        Components object
        componentId, pageId, componentTypeId, order, componentName, helpText, componentType, showInSelfService, isComponentInteractive, isComponentInvalid, componentErrorMessages, isReadOnlyForEndUser, childComponentCount, parentComponent, components, extraProperties
        .EXAMPLE
        PS> Get-JuribaEvergreenSelfServiceComponent @dwparams -ServiceId 1
        PS> Get-JuribaEvergreenSelfServiceComponent @dwparams -ServiceId 1 -PageId 7
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$ServiceId,
        [Parameter(Mandatory = $false)]
        [int]$PageId
    )

    $headers = @{'x-api-key' = $APIKey }
    $uri = "{0}/apiv1/admin/selfservices/{1}/pages" -f $Instance, $ServiceId
    
    #Try to create SS component
    try {
        $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType 'application/json'
        if($result.StatusCode -eq 200) {
            $resulttable = $result.Content | ConvertFrom-Json

            if($PageId -gt 0) {
                [array]$results = ($resulttable | Where-Object {$_.pageId -eq $PageId}).components
                $results += ($resulttable | Where-Object {$_.pageId -eq $PageId}).components.components
                return $results                    
            }
            else {
                [array]$results = $resulttable.components
                $results += $resulttable.components.components
                return $results
            }
        }
    }
    catch {
        Write-Error $_
    }
}