Function New-DwDashboardBarWidget {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$DashboardId,
        [Parameter(Mandatory = $true)]
        [int]$SectionId,
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [int]$ListId,
        [Parameter(Mandatory = $true)]
        [string]$SplitBy,
        [Parameter(Mandatory = $false)]
        [string]$OrderByField = $null,
        [Parameter(Mandatory = $false)]
        [bool]$OrderByDescending = $false,
        [Parameter(Mandatory = $false)]
        [string]$CategoriseBy = $null
    )
        $body        = @{
            "widgetType"                = "Bar"
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
            "orderByDescending"         = if ($OrderByDescending) { $true } else { $false }
            "orderById"                 = if ($OrderByField) { if ($OrderByField -eq "Count") { 2 } else { 1 } } else { $null }
            "orderByField"              = $OrderByField
            "showLegend"                = $true
            "orientationIsVertical"     = $false
            "layout"                    = $null
            "displayDataLabels"         = $false
            "categoriseBy"              = $CategoriseBy
            "categorisationViewType"    = "Stacked"
            "categoriseByMaximumValues" = 10
        } | ConvertTo-Json

        $contentType = "application / json"
        $headers = @{ 'X-API-KEY' = $ApiKey }
        $uri = "{0}/apiv1/dashboard/{1}/section/{2}/widget"  -f  $instance, $DashboardId, $SectionId

        if ($PSCmdlet.ShouldProcess($Title)) {
            Invoke-WebRequest -Uri $uri -Headers $headers -Body $body -Method POST -ContentType $contentType
        }


    }