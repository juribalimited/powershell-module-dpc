function New-JuribaDashboardDonutWidget {
    [alias("New-DwDashboardDonutWidget")]
    <#
        .SYNOPSIS
        Creates a new dashboard donut widget.
        .DESCRIPTION
        Creates a new dashboard donut widget using the Dashworks API v1, Supporting special characters in the naming.
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER DashboardId
        Dashboard ID to add the widget to.
        .PARAMETER SectionId
        Section ID to add the widget to.
        .PARAMETER Title
        Title of the new widget.
        .PARAMETER ListId
        ListId for the widget.
        .PARAMETER SplitBy
        Object to split the result by, typically a task, custom field, column from a list or empty
        .PARAMETER OrderByField
        Defines the object that orders by Split Value = 1, Aggregate Value = 2, Status = 3, Severity = 4, Chronological = 5, Display Order = 6
        .PARAMETER OrderByDescending
        Boolean value to define if order by by descending true or false, false by default
        .PARAMETER ObjectType
        Object type that this new widget applies to. Accepts Devices, Users, Applications, Mailboxes. Defaults to Devices
        .PARAMETER AggregateFunction
        Function used for the widget. Accepts Count, Count Distinct, Max, Min, Sum, Average
        .PARAMETER AggregateBy
        Normally custom field/task in a special format: customField_[data type ID]_[custom field ID] or project_task_[project ID]_[Task ID]_[Data type ID]_Task. Defaults to empty
        .PARAMETER MaximumValues
        Maximum value to display for the widget
        .PARAMETER displayDataLabels
        Boolean value to display data labels, default to false
        .PARAMETER Legend
        Position of legend "None","Right","Left","Top","Bottom" in the widget
        .OUTPUTS
        widgetId
        .EXAMPLE
        PS> New-JuribaDashboardDonutWidget @dwparams -DashboardId 46 -SectionId 84 -Title "Application Rationalisation" -ListId 337 -SplitBy "project_1_applicationRationalisation" -OrderByField "Split Value" -OrderByDescending $true -ObjectType "Applications" -AggregateFunction "count" -Legend "Top"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
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
        [Parameter(Mandatory=$false)]
        [ValidateSet ("Users","Devices","Applications","Mailboxes")]
        [string]$ObjectType = "Devices",
        [Parameter(Mandatory=$true)]
        [ValidateSet ("Count","Count Distinct","Max","Min","Sum","Average")]
        [string]$AggregateFunction = "Count",
        [parameter(Mandatory = $false)]
        [string]$AggregateBy = "",
        [Parameter(Mandatory=$false)]
        [ValidateRange(1,100) ]
        [int]$MaximumValues = 10,
        [Parameter(Mandatory=$false)]
        [boolean]$displayDataLabels = $false,
        [Parameter(Mandatory=$false)]
        [ValidateSet ("None","Right","Left","Top","Bottom")]
        [string]$Legend = "Bottom"
    )

    switch ($ObjectType){
        "Users" {$ObjectTypeID = 1}
        "Devices" {$ObjectTypeID = 2}
        "Applications" {$ObjectTypeID = 3}
        "Mailboxes" {$ObjectTypeID = 4}
    }
    switch ($AggregateFunction){
        "Count" {$AggregateFunctionID = 1}
        "Count Distinct" {$AggregateFunctionID = 2}
        "Sum" {$AggregateFunctionID = 3}
        "Min" {$AggregateFunctionID = 4}
        "Max" {$AggregateFunctionID = 5}
        "Average" {$AggregateFunctionID = 6}
    }
    switch ($Legend){
        "None" {$LegendValue = 1}
        "Right" {$LegendValue = 2}
        "Left" {$LegendValue = 3}
        "Top" {$LegendValue = 4}
        "Bottom" {$LegendValue = 4}
    }
    switch ($OrderByField){
        "Split Value" {$OrderById = 1}
        "Aggregate Value" {$OrderById = 2}
        "Status" {$OrderById = 3}
        "Severity" {$OrderById = 4}
        "Chronological" {$OrderById = 5}
        "Display Order" {$OrderById = 6}
    }

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $body = @{
            "widgetType"                = "Donut"
            "displayOrder"              = 0
            "title"                     = $Title
            "listId"                    = if ($null -eq $ListId -or $ListId -eq 0) { $null } else { $ListId }
            "listObjectType"            = $ObjectType
            "listObjectTypeId"          = $ObjectTypeID
            "colourSchemeId"            = 3
            "widgetValuesColours"       = @()
            "colourTemplateId"          = 1
            "aggregateFunctionId"       = $AggregateFunctionID
            "maximumValues"             = $MaximumValues
            "drilldownEnabled"          = $true
            "maxRows"                   = 0
            "maxColumns"                = 0
            "cardTypeIsAggregate"       = $false
            "splitBy"                   = $SplitBy
            "aggregateBy"               = $AggregateBy
            "orderByDescending"         = $OrderByDescending
            "orderById"                 = $OrderById
            "legend"                    = $LegendValue
            "orientationIsVertical"     = $false
            "layout"                    = $null
            "displayDataLabels"         = $displayDataLabels
            "categoriseBy"              = ""
            "categorisationViewType"    = "None"
            "categoriseByMaximumValues" = 10
        }
        
        $jsonbody = $body | ConvertTo-Json
        $contentType = "application/json"
        $headers = @{ 'X-API-KEY' = $ApiKey }
		$uri = "{0}/apiv1/dashboard/{1}/section/{2}/widget" -f $Instance, $DashboardId, $SectionId

        if ($PSCmdlet.ShouldProcess($Title)) {
            $result = Invoke-WebRequest -Uri $uri -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -Method POST -ContentType $contentType
            return ($result.Content | ConvertFrom-Json).WidgetId
        }
    }
    else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}