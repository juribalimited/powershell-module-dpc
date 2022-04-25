Function Remove-DwDashboard {
    <#
    .SYNOPSIS

    Deletes a dashboard.

    .DESCRIPTION

    Deletes a dashboard using Dashworks API v1.

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Instance,
        [Parameter(Mandatory = $true)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$DashboardId
    )

    $uri = "{0}/apiv1/dashboard/{1}" -f $Instance, $DashboardId
    $headers = @{'x-api-key' = $APIKey }

    if ($PSCmdlet.ShouldProcess($AutomationId)) {
        Invoke-WebRequest -Uri $uri -Method DELETE -Headers $headers -ContentType 'application/json'
    }
}