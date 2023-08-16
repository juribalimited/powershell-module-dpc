function Get-JuribaEvergreenSelfServiceBaseURL {
    [alias("Get-DwEvergreenSelfServiceBaseURL")]
    <#
        .SYNOPSIS
        Gets the base URL for Evergreen SelfService.
        .DESCRIPTION
        Gets the base URL for Evergreen SelfService using Dashworks API v1.
        .PARAMETER Instance
        Dashworks instance. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Dashworks API Key.
        .OUTPUTS
        settingValue
        .EXAMPLE
        PS>  Get-JuribaEvergreenSelfServiceBaseURL @dwparams
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey
    )

    $uri = "{0}/apiv1/admin/selfservicesettings/baseurl" -f $Instance
    $headers = @{'x-api-key' = $APIKey }
    
    #Try to get SS URL
    try {
        $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers
        if ($result.StatusCode -eq 200) {
            return ($result.content | ConvertFrom-Json).settingValue
        }
        else {
            throw "Error getting self service url."
        }
    }
    catch {
        Write-Error $_
    }
}