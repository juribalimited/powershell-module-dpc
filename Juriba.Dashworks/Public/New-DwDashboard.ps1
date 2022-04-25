Function New-DwDashboard {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [ValidateSet("SharedAllUsersReadOnly")]
        [string]$SharedAccessType
    )

    $body = @{
        "dashboardName"                 = $Name
        "sharedAccessType"              = $SharedAccessType
    } | ConvertTo-Json

    $contentType = "application/json"
    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = "{0}/apiv1/dashboard" -f $Instance

    if ($PSCmdlet.ShouldProcess($Name)) {
        $result = Invoke-WebRequest -Uri $uri -Headers $headers -Body $body -Method POST -ContentType $contentType
        return ($result.Content | ConvertFrom-Json)
    }


}