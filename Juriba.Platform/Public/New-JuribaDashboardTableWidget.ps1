function New-JuribaDashboardTableWidget {
    [alias("New-DwDashboardTableWidget")]
    <#
        .SYNOPSIS
        Creates a new dashboard table widget.
        .DESCRIPTION
        Creates a new dashboard table widget using the Dashworks API v1, Supporting special characters in the naming.
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
        Maximum value to display for the widget, default to 10
        .PARAMETER OrientationIsVertical
        Boolean value to define if orientation is vertical, default to false
        .PARAMETER splitByGroupDatesBy
        Option to choose to group by "Month","Day","Year","None","Week from Monday","Week from Sunday"
        .PARAMETER splitByIncludeEmptyDates
        Boolean value to include empty dates, default to false
        .OUTPUTS
        widgetId
        .EXAMPLE
        PS> New-JuribaDashboardTableWidget @dwparams -DashboardId 46 -SectionId 84 -Title "Missed deployments after 10 days" -ListId 337 -SplitBy "project_task_1_15_2_Task" -OrderByField "Split Value" -ObjectType "Applications" -AggregateFunction "count" -MaximumValues 99 -OrientationIsVertical $true -splitByGroupDatesBy "Day"
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
        [Parameter(Mandatory=$false)]
        [ValidateSet ("Count","Count Distinct","Max","Min","Sum","Average")]
        [string]$AggregateFunction = "Count",
        [parameter(Mandatory = $false)]
        [string]$AggregateBy = "",
        [Parameter(Mandatory=$false)]
        [ValidateRange(1,100) ]
        [int]$MaximumValues = 10,
        [Parameter(Mandatory=$false)]
        [boolean]$OrientationIsVertical = $true,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Month","Day","Year","None","Week from Monday","Week from Sunday")]
        [string]$splitByGroupDatesBy = "None",
        [Parameter(Mandatory=$false)]
        [boolean]$splitByIncludeEmptyDates = $false
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
    switch ($splitByGroupDatesBy){
        "None" {$splitByGroupDatesById = 1}
        "Day" {$splitByGroupDatesById = 2}
        "Week from Monday" {$splitByGroupDatesById = 3}
        "Week from Sunday" {$splitByGroupDatesById = 4}
        "Month" {$splitByGroupDatesById = 5}
        "Year" {$splitByGroupDatesById = 6}
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
            "widgetType"                = "Table"
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
            "splitByGroupDatesById"     = $splitByGroupDatesById
            "splitByIncludeEmptyDates"  = $splitByIncludeEmptyDates
            "aggregateBy"               = $AggregateBy
            "orderByDescending"         = $OrderByDescending
            "orderById"                 = $OrderById
            "legend"                    = 5
            "orientationIsVertical"     = $OrientationIsVertical
            "layout"                    = $null
            "displayDataLabels"         = $false
            "categoriseBy"              = ""
            "categorisationViewType"    = "None"
            "categoriseByMaximumValues" = $null
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