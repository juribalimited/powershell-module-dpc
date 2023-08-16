Function New-JuribaDashboard {
    [alias("New-DwDashboard")]
    <#
        .SYNOPSIS
        Creates a new dashboard.
        .DESCRIPTION
        Creates a new dashboard using Dashworks API v1.
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER Name
        Name of the dashboard.
        .PARAMETER SharedAccessType
        Choose from one of the type. Private, SharedAllUsersEdit, SharedAllUsersReadOnly, SharedSpecificUsers
        .OUTPUTS
        Dashboard object
        .EXAMPLE
        PS> New-JuribaDashboard -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -Name "W11" -SharedAccessType "SharedAllUsersReadOnly"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Private","SharedAllUsersEdit","SharedAllUsersReadOnly","SharedSpecificUsers")]
        [string]$SharedAccessType
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
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

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}