Function New-JuribaDashboardCardWidget {
    [alias("New-DwDashboardCardWidget")]
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
        [int]$ListId
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
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
                "legend"                    = 5
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

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
