Function Invoke-DwAutomation {
    <#
    .SYNOPSIS

    Runs one or more automations.

    .DESCRIPTION

    Runs one or more automations using Dashworks API v1.

    .PARAMETER Instance

    Dashworks instance. For example, https://myinstance.dashworks.app:8443

    .PARAMETER APIKey

    Dashworks API Key.

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
        [Parameter(Mandatory = $true)]
        [string]$Instance,
        [Parameter(Mandatory = $true)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int[]]$Ids
    )

    $body = @{"AutomationIds" = $Ids} | ConvertTo-Json

    $uri = "{0}/apiv1/admin/automations/run-command" -f $Instance
    $headers = @{'x-api-key' = $APIKey }

    if ($PSCmdlet.ShouldProcess($Ids -Join ",")) {
        Invoke-WebRequest -Uri $uri -Method PATCH -Headers $headers -Body $body -ContentType 'application/json'
    }
}
