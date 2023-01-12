Function Invoke-DwAutomation {
    <#
    .SYNOPSIS

    Runs one or more automations.

    .DESCRIPTION

    Runs one or more automations using Dashworks API v1.

    .PARAMETER Instance

    Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

    .PARAMETER APIKey

    Optional. API key to be provided if not authenticating using Connect-Juriba.

    .PARAMETER Name

    Name of the new automation.

    .PARAMETER Ids

    Array of Automation Id's to run.

    .OUTPUTS

    None.

    .EXAMPLE

    PS> Invoke-DwAutomation -Instance "https://myinstance.dashworks.app" -APIKey "xxxxx" -Ids @(1,2,3)
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int[]]$Ids
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $body = @{"AutomationIds" = $Ids} | ConvertTo-Json

        $uri = "{0}/apiv1/admin/automations/run-command" -f $Instance
        $headers = @{'x-api-key' = $APIKey }
    
        if ($PSCmdlet.ShouldProcess($Ids -Join ",")) {
            Invoke-WebRequest -Uri $uri -Method PATCH -Headers $headers -Body $body -ContentType 'application/json'
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
