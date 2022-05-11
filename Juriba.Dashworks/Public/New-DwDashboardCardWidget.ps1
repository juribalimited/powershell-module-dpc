Function New-DwDashboardCardWidget {

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
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [int]$ListId
    )

    $request = @{
        Uri         = ($Instance + "/apiv1/dashboard/" + $DashboardId + "/section/" + $SectionId + " /widget")
        Method      = "Post"
        Body        = @{
            "widgetType"                = "Card"
            "displayOrder"              = 0
            "title"                     = $Title
            "listId"                    = $ListId
            "listObjectType"            = "devices"
            "listObjectTypeId"          = 2
            "colourSchemeId"            = 3
            "widgetValuesColours"       = @()
            "colourTemplateId"          = 10
            "aggregateFunctionId"       = 1
            "maximumValues"             = $null
            "drilldownEnabled"          = $true
            "maxRows"                   = 0
            "maxColumns"                = 0
            "cardTypeIsAggregate"       = $true
            "splitBy"                   = ""
            "aggregateBy"               = ""
            "orderByDescending"         = $null
            "orderById"                 = $null
            "orderByField"              = $null
            "showLegend"                = $false
            "orientationIsVertical"     = $false
            "layout"                    = "IconAndText"
            "displayDataLabels"         = $false
            "categoriseBy"              = ""
            "categorisationViewType"    = "None"
            "categoriseByMaximumValues" = $null
        } | ConvertTo-Json
        ContentType = "application/json"
        Headers     = @{
            'X-API-KEY' = $APIKey
        }
    }

    if ($PSCmdlet.ShouldProcess($Title)) {
        Invoke-RestMethod @request | Out-Null
    }
}
