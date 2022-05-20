Function Set-DwDashboardSection {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
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
}