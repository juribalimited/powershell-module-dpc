Function Set-DwDashboardSection {
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
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Dw before proceeding."
    }
}