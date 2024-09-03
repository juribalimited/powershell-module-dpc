function New-JuribaDashboardListWidget {
    [alias("New-DwDashboardListWidget")]
    <#
        .SYNOPSIS
        Creates a new dashboard list widget.
        .DESCRIPTION
        Creates a new dashboard list widget using the Dashworks API v1, Supporting special characters in the naming.
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
        .PARAMETER maxRows
        Maximum number of rows 1 to 1000
        .PARAMETER maxColumns
        Maximum number of columns 1 to 1000
        .OUTPUTS
        widgetId
        .EXAMPLE
        PS> New-JuribaDashboardListWidget @dwparams -DashboardId 46 -SectionId 84 -Title "Today's Direct Ships" -ListId 337 -maxRows 1000 -maxColumns 10
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
        [ValidateRange(1,1000) ]
        [string]$maxRows = 100,
        [Parameter(Mandatory=$false)]
        [ValidateRange(1,1000) ]
        [string]$maxColumns = 10
    )

    switch ($ObjectType){
        "Users" {$ObjectTypeID = 1}
        "Devices" {$ObjectTypeID = 2}
        "Applications" {$ObjectTypeID = 3}
        "Mailboxes" {$ObjectTypeID = 4}
    }

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
		$uri = "{0}/apiv1/dashboard/{1}/section/{2}/widget" -f $Instance, $DashboardId, $SectionId						
        $Body = @{
            "widgetType"                = "List"
            "displayOrder"              = 0
            "title"                     = $Title
            "listId"                    = if ($null -eq $ListId -or $ListId -eq 0) { $null } else { $ListId }
            "listObjectType"            = $ObjectType
            "listObjectTypeId"          = $ObjectTypeId
            "colourSchemeId"            = 3
            "widgetValuesColours"       = @()
            "colourTemplateId"          = 1
            "aggregateFunctionId"       = $null
            "maximumValues"             = $null
            "drilldownEnabled"          = $false
            "maxRows"                   = $maxRows
            "maxColumns"                = $maxColumns
            "cardTypeIsAggregate"       = $false
            "splitBy"                   = ""
            "aggregateBy"               = ""
            "orderByDescending"         = $null
            "orderById"                 = $null
            "orderByField"              = $null
            "legend"                    = 1
            "orientationIsVertical"     = $false
            "layout"                    = $null
            "displayDataLabels"         = $false
            "categoriseBy"              = ""
            "categorisationViewType"    = "None"
            "categoriseByMaximumValues" = $null
        }
        
        $jsonbody = $body | ConvertTo-Json
        $ContentType = "application/json"
        $Headers     = @{
            'X-API-KEY' = $APIKey			 
        }
    
        if ($PSCmdlet.ShouldProcess($Title)) {
            $result = Invoke-WebRequest -Uri $uri -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -Method POST -ContentType $contentType
            return ($result.Content | ConvertFrom-Json).WidgetId
        }
    }
    else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}