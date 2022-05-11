Function Get-DwDashboard {
    <#
    .SYNOPSIS

    Gets all Dashboards.

    .DESCRIPTION

    Gets all Dashboards using Dashworks API v1.

    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [Parameter(Mandatory=$false)]
        [int]$DashboardId
    )

    $contentType = "application/json"
    $headers = @{ 'X-API-KEY' = $ApiKey }

    if ($DashboardId) {
        $uri = "{0}/apiv1/dashboard/{1}" -f $Instance, $DashboardId
    }
    else {
        $uri = "{0}/apiv1/dashboard" -f $Instance
    }


    try {
        $result = Invoke-WebRequest -Uri $uri -Headers $headers -Method GET -ContentType $contentType
        return ($result.Content | ConvertFrom-Json)
    }
    catch {
        Write-Error $_
    }
}