Function Remove-JuribaDashboard {
    <#
    .SYNOPSIS

    Deletes a dashboard.

    .DESCRIPTION

    Deletes a dashboard using Dashworks API v1.

    .PARAMETER Instance

    Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

    .PARAMETER APIKey

    Optional. API key to be provided if not authenticating using Connect-Juriba.

    .PARAMETER DashboardId

    Id of the dashboard to delete.

    .EXAMPLE

    PS> Remove-JuribaDashboard -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -DashboardId 12

    #>
    [alias("Remove-DwDashboard")]

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$DashboardId
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $uri = "{0}/apiv1/dashboard/{1}" -f $Instance, $DashboardId
        $headers = @{'x-api-key' = $APIKey }
    
        if ($PSCmdlet.ShouldProcess($DashboardId)) {
            Invoke-WebRequest -Uri $uri -Method DELETE -Headers $headers -ContentType 'application/json'
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}