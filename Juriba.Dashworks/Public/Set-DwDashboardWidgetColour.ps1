Function Set-DwDashboardWidgetColour {
    <#
    .SYNOPSIS

    Gets all Dashboards.

    .DESCRIPTION

    Gets all Dashboards using Dashworks API v1.

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$DashboardId,
        [Parameter(Mandatory = $true)]
        [int]$SectionId,
        [Parameter(Mandatory = $true)]
        [int]$WidgetId,
        [ValidateScript({
            Test-Json $_
        },
        ErrorMessage = "JsonBody is not valid json."
        )]
        [parameter(Mandatory=$true)]
        [string]$JsonBody
    )

    $contentType = "application/json"
    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = "{0}/apiv1/dashboard/{1}/section/{2}/widget/{3}" -f $Instance, $DashboardId, $SectionId, $WidgetId

    try {
        if ($PSCmdlet.ShouldProcess($Name)) {
            $result = Invoke-WebRequest -Uri $uri -Headers $headers -Method PUT -ContentType $contentType -Body $JsonBody
            return $result
        }
    }
    catch {
        Write-Error $_
    }
}