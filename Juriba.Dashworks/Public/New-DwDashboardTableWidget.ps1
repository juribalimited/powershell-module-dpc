Function New-DwDashboardTableWidget {

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
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [int]$ListId,
        [Parameter(Mandatory=$true)]
        [string]$SplitBy,
        [Parameter(Mandatory=$false)]
        [string]$OrderByField = $null,
        [Parameter(Mandatory=$false)]
        [bool]$OrderByDescending = $false,
        [Parameter(Mandatory=$false)]
        [string]$CategoriseBy = $null
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $request = @{
            Uri         = ($Instance + "/apiv1/dashboard/" + $DashboardId + "/section/" + $SectionId + "/widget")
            Method      = "Post"
            Body        = @{
                "widgetType"                = "Table"
                "displayOrder"              = 0
                "title"                     = $Title
                "listId"                    = $ListId
                "listObjectType"            = "devices"
                "listObjectTypeId"          = 2
                "colourSchemeId"            = 3
                "widgetValuesColours"       = @()
                "colourTemplateId"          = 1
                "aggregateFunctionId"       = 1
                "maximumValues"             = 10
                "drilldownEnabled"          = $true
                "maxRows"                   = 0
                "maxColumns"                = 0
                "cardTypeIsAggregate"       = $false
                "splitBy"                   = $SplitBy
                "aggregateBy"               = ""
                "orderByDescending"         = $OrderByDescending
                "orderById"                 = if ($OrderByField) { if ($OrderByField -eq "Count") { 2 }else { 1 } }else { $null }
                "orderByField"              = $OrderByField
                "legend"                    = 5
                "orientationIsVertical"     = $true
                "layout"                    = "IconAndText"
                "displayDataLabels"         = $false
                "categoriseBy"              = $CategoriseBy
                "categorisationViewType"    = "None"
                "categoriseByMaximumValues" = $null
            } | ConvertTo-Json
            ContentType = "application / json"
            Headers     = @{
                'X-API-KEY' = $APIKey
            }
        }
    
        if ($PSCmdlet.ShouldProcess($Title)) {
            Invoke-RestMethod @request | Out-Null
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Dw before proceeding."
    }
}