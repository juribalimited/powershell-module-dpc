function Set-JuribaEvergreenSelfServiceBaseURL {
    [alias("Set-DwEvergreenSelfServiceBaseURL")]
    <#
        .SYNOPSIS
        Updates the base URL for Evergreen SelfService.
        .DESCRIPTION
        Updates the base URL for Evergreen SelfService using Dashworks API v1.
        .PARAMETER Instance
        Dashworks instance. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Dashworks API Key.
        .PARAMETER URL
        URL for the new self service.
        .OUTPUTS
        settingValue
        .EXAMPLE
        PS>  Set-JuribaEvergreenSelfServiceBaseURL @dwparams -URL "https://myinstance.dashworks.app"
    #>						  
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [string]$URL
    )
	
    $payload  = @{}
    $payload.Add("settingValue", $url)

    $jsonbody = $payload | ConvertTo-Json

    $uri = "{0}/apiv1/admin/selfservicesettings/baseurl" -f $Instance
    $headers = @{'x-api-key' = $APIKey }
    
    #Try to update SS URL
    try {
        $result = Invoke-WebRequest -Uri $uri -Method PUT -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType 'application/json'
        if ($result.StatusCode -eq 200)
        {
            return ($result.content | ConvertFrom-Json).settingValue
        }
        else {
            throw "Error updating self service url."
        }
    }
    catch {
            Write-Error $_
    }
}