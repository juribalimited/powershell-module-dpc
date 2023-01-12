Function Set-DwDashboardWidgetColour {
    <#
    .SYNOPSIS

    Gets all Dashboards.

    .DESCRIPTION

    Gets all Dashboards using Dashworks API v1.

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
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
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $contentType = "application/json"
        $headers = @{ 'X-API-KEY' = $ApiKey }
        $uri = "{0}/apiv1/dashboard/{1}/section/{2}/widget/{3}" -f $Instance, $DashboardId, $SectionId, $WidgetId
    
        try {
            if ($PSCmdlet.ShouldProcess($WidgetId)) {
                $result = Invoke-WebRequest -Uri $uri -Headers $headers -Method PUT -ContentType $contentType -Body $JsonBody
                return $result
            }
        }
        catch {
            Write-Error $_
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}