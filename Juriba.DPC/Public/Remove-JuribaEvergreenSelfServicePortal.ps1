function Remove-JuribaEvergreenSelfServicePortal {
    <#
		.SYNOPSIS
		Deletes a self service portal.
		.DESCRIPTION
		Deletes a self service portal using Dashworks API v1.
		.PARAMETER Instance
		Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app
		.PARAMETER APIKey
		Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ServiceId
        ServiceID for the self service to be deleted.
        .OUTPUTS
        The self service portal has been deleted
		.EXAMPLE
		PS> Remove-JuribaEvergreenSelfServicePortal -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -ServiceId 1
	#>
    [alias("Remove-DwEvergreenSelfServicePortal")]						 
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$ServiceId
    )
	
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }
    
    if ($APIKey -and $Instance) {
        $body = @{
            serviceIds = @($ServiceId)
            actionRequestType = "Delete"
        } | ConvertTo-Json
    
        $uri = "{0}/apiv1/admin/selfservices" -f $Instance
        $headers = @{'x-api-key' = $APIKey }
    
        try {
            if ($PSCmdlet.ShouldProcess($ServiceId)) {
                $result = Invoke-WebRequest -Uri $uri -Method DELETE -Body $body -Headers $headers -ContentType 'application/json'
                if($result.StatusCode -eq 200) {
                    return "The self service portal has been deleted"
                }
            }
        }
        catch {
            Write-Error $_
        }
    }
	else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}