Function Get-DwDashboard {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey
    )

    $contentType = "application/json"
    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = "{0}/apiv1/dashboard" -f $Instance

    $result = Invoke-WebRequest -Uri $uri -Headers $headers -Method GET -ContentType $contentType
    return ($result.Content | ConvertFrom-Json)

}