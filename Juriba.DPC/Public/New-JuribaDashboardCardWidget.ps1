function New-JuribaDashboardCardWidget {
    [alias("New-DwDashboardCardWidget")]
    <#
        .SYNOPSIS
        Creates a new dashboard card widget.
        .DESCRIPTION
        Creates a new dashboard card widget using the Dashworks API v1, Supporting special characters in the naming.
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
        .PARAMETER ObjectType
        Object type that this new widget applies to. Accepts Devices, Users, Applications, Mailboxes. Defaults to Devices
        .PARAMETER AggregateFunction
        Function used for the widget. Accepts Count, Count Distinct, Max, Min, Sum, Average
        .PARAMETER AggregateBy
        Normally custom field/task in a special format: customField_[data type ID]_[custom field ID] or project_task_[project ID]_[Task ID]_[Data type ID]_Task. Defaults to empty
        .PARAMETER ColourTemplate
        Optional. Sets the type of updates allowed for this custom field. Either Directly or ETL. Defaults to Directly.
        .OUTPUTS
        widgetId
        .EXAMPLE
        PS> New-JuribaDashboardCardWidget @dwparam -DashboardId 1 -SectionId 2 -Title "Windows 11 Upgrade Scope" -ListId 2 -AggregateFunction "Count" -AggregateBy "" -ColourTemplate 1
    #>
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
        [Parameter(Mandatory=$false)]
        [ValidateSet ("Users","Devices","Applications","Mailboxes")]
        [string]$ObjectType = "Devices",
        [Parameter(Mandatory=$false)]
        [ValidateSet ("Count","Count Distinct","Max","Min","Sum","Average")]
        [string]$AggregateFunction = "Count",
        [parameter(Mandatory = $false)]
        [string]$AggregateBy = "",
        [Parameter(Mandatory=$false)]
        [int]$ColourTemplate = 1 ##1 Black , 2 Blue, 3 Turquoise, 4 Red, 5 Brown, 6 Pink, 7 Amber, 8 Orange, 9 Purple, 10 Green, 11 Grey, 12 Silver        
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

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
		$Uri = "{0}/apiv1/dashboard/{1}/section/{2}/widget" -f $Instance, $DashboardId, $SectionId
        $Body = @{
            "widgetType"                = "Card"
            "displayOrder"              = 0
            "title"                     = $Title
            "listId"                    = if ($null -eq $ListId -or $ListId -eq 0) { $null } else { $ListId }
            "listObjectType"            = $ObjectType
            "listObjectTypeId"          = $ObjectTypeId
            "colourSchemeId"            = 3
            "widgetValuesColours"       = @()
            "colourTemplateId"          = $ColourTemplate
            "aggregateFunctionId"       = $AggregateFunctionID
            "maximumValues"             = $null
            "drilldownEnabled"          = $true
            "maxRows"                   = 0
            "maxColumns"                = 0
            "cardTypeIsAggregate"       = $true
            "splitBy"                   = ""
            "aggregateBy"               = $AggregateBy
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
        }
        
        $jsonbody = $body | ConvertTo-Json
        $ContentType = "application/json"
        $headers     = @{
            'X-API-KEY' = $APIKey
        }
    }

    if ($PSCmdlet.ShouldProcess($Title)) {
        
        $result = Invoke-WebRequest -Uri $uri -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -Method POST -ContentType $contentType
        return ($result.Content | ConvertFrom-Json).WidgetId
    }
    else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}