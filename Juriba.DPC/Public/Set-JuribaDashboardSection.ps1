Function Set-JuribaDashboardSection {
    <#
        .SYNOPSIS
        Updates a section on a dashboard.

        .DESCRIPTION
        Updates the name, description, layout and visibility of a section on a Juriba DPC dashboard using API v1.
        All section properties are sent on every call, so any parameter you leave out is reset to its default value.

        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER DashboardId
        Id of the dashboard that contains the section.

        .PARAMETER SectionId
        Id of the section to update.

        .PARAMETER Name
        Optional. Name of the section. Defaults to an empty string.

        .PARAMETER Description
        Optional. Description of the section. Defaults to an empty string.

        .PARAMETER DisplayOrder
        Optional. Position of the section on the dashboard. Defaults to 1.

        .PARAMETER Width
        Optional. Width of the section. Defaults to 2.

        .PARAMETER Hidden
        Optional. Whether the section is hidden. Defaults to $false.

        .PARAMETER Collapsed
        Optional. Whether the section is collapsed. Defaults to $false.

        .PARAMETER Expanded
        Optional. Whether the section is expanded. Defaults to $true.

        .OUTPUTS
        None.

        .EXAMPLE
        PS> Set-JuribaDashboardSection -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -DashboardId 12 -SectionId 3 -Name "Readiness" -DisplayOrder 2 -Width 1
    #>
    [alias("Set-DwDashboardSection")]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory=$true)]
        [int]$DashboardId,
        [Parameter(Mandatory=$true)]
        [int]$SectionId,
        [Parameter(Mandatory=$false)]
        [string]$Name = "",
        [Parameter(Mandatory=$false)]
        [string]$Description = "",
        [Parameter(Mandatory=$false)]
        [int]$DisplayOrder = 1,
        [Parameter(Mandatory=$false)]
        [int]$Width = 2,
        [Parameter(Mandatory=$false)]
        [bool]$Hidden = $false,
        [Parameter(Mandatory=$false)]
        [bool]$Collapsed = $false,
        [Parameter(Mandatory=$false)]
        [bool]$Expanded = $true
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $request = @{
            Uri         = ($Instance + "/apiv1/dashboard/" + $DashboardId + "/section/" + $SectionId)
            Method      = "Put"
            Body        = @{
                "name"         = $Name
                "description"  = $Description
                "hidden"       = $Hidden
                "collapsed"    = $Collapsed
                "width"        = $Width
                "sectionId"    = $SectionId
                "displayOrder" = $DisplayOrder
                "expanded"     = $Expanded
    
            } | ConvertTo-Json
            ContentType = "application/json"
            Headers     = @{
                'X-API-KEY' = $ApiKey
            }
        }
    
        if ($PSCmdlet.ShouldProcess($Name)) {
            Invoke-RestMethod @request | Out-Null
        }
    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}