function Set-JuribaEvergreenSelfServiceBaseURL {
    <#
        .SYNOPSIS
        Updates the base URL for Evergreen SelfService.
        .DESCRIPTION
        Updates the base URL for Evergreen SelfService using Dashworks API v1.
        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER URL
        URL for the new self service.
        .OUTPUTS
        settingValue
        .EXAMPLE
        PS>  Set-JuribaEvergreenSelfServiceBaseURL -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -URL "https://myinstance.dpc.juriba.app"
    #>
    [alias("Set-DwEvergreenSelfServiceBaseURL")]
    [CmdletBinding(SupportsShouldProcess)]
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
        if($PSCmdlet.ShouldProcess($URL)) {
            $result = Invoke-WebRequest -Uri $uri -Method PUT -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType 'application/json'
            if ($result.StatusCode -eq 200)
            {
                return ($result.content | ConvertFrom-Json).settingValue
            }
            else {
                throw "Error updating self service url."
            }
        }
    }
    catch {
        Write-Error $_
    }
}