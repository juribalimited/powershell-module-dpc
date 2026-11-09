Function New-JuribaDashboardSection {
    <#
        .SYNOPSIS
        Creates a new section on a dashboard.

        .DESCRIPTION
        Creates a new section on a Juriba DPC dashboard using API v1.

        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER DashboardId
        Id of the dashboard to add the section to.

        .PARAMETER Width
        Optional. Width of the new section. Defaults to 2.

        .OUTPUTS
        The Id of the new section.

        .EXAMPLE
        PS> New-JuribaDashboardSection -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -DashboardId 12 -Width 1
    #>
    [alias("New-DwDashboardSection")]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory=$true)]
        [int]$DashboardId,
        [Parameter(Mandatory=$false)]
        [int]$Width = 2
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $request = @{
            Uri         = ($Instance + "/apiv1/dashboard/" + $DashboardId + "/section/")
            Method      = "Post"
            Body        = @{
                "width" = $Width
            } | ConvertTo-Json
            ContentType = "application/json"
            Headers     = @{
                'X-API-KEY' = $APIKey
            }
        }
    
        if ($PSCmdlet.ShouldProcess($DashboardId)) {
            $response = Invoke-RestMethod @request
            $response.sectionId
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
