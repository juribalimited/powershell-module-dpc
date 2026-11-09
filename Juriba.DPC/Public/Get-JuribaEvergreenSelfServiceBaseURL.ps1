function Get-JuribaEvergreenSelfServiceBaseURL {
    <#
        .SYNOPSIS
        Gets the base URL for Evergreen SelfService.
        .DESCRIPTION
        Gets the base URL for Evergreen SelfService using Dashworks API v1.
        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .OUTPUTS
        settingValue
        .EXAMPLE
        PS>  Get-JuribaEvergreenSelfServiceBaseURL -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx"
    #>
    [alias("Get-DwEvergreenSelfServiceBaseURL")]
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