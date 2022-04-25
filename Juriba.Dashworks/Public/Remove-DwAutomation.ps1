Function Remove-DwAutomation {
    <#
    .SYNOPSIS

    Deletes an automation.

    .DESCRIPTION

    Deletes an automation using Dashworks API v1.

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Instance,
        [Parameter(Mandatory = $true)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$AutomationId
    )
    
    $body = @{
        automationIds = @($AutomationId)
    } | ConvertTo-Json

    $uri = "{0}/apiv1/admin/automations" -f $Instance
    $headers = @{'x-api-key' = $APIKey }

    if ($PSCmdlet.ShouldProcess($AutomationId)) {
        Invoke-WebRequest -Uri $uri -Method DELETE -Body $body -Headers $headers -ContentType 'application/json'
    }
}