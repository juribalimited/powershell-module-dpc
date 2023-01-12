Function Get-DwDashboard {
    <#
    .SYNOPSIS

    Gets all Dashboards.

    .DESCRIPTION

    Gets all Dashboards using Dashworks API v1.

    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory=$false)]
        [int]$DashboardId
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
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

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Dw before proceeding."
    }
}