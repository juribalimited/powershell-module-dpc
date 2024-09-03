function Get-JuribaCapacitySlot {
    [alias("Get-DwCapacitySlot")]
    <#
        .SYNOPSIS
        Returns all capacity slots in US English.
        .DESCRIPTION
        Returns all capacity slots using API v1
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ProjectID
        ID of the project
        .OUTPUTS
        Capacity slot objects
        slotId, projectId, slotName, displayOrder, slotAvailableFrom, slotAvailableTo, slotStartTime, slotEndTime, monday, tuesday, wednesday, thursday, friday, saturday, sunday, allUnits, allRequestTypes, allTeams, objectTypeId, capacityModeId, capacityOverrides, capacitySlotLanguages, objectTaskDateValues, requestTypes, teams, capacityUnits, capacityMode, objectType, projectTasks, taskRules, displayName, requestTypesNames, teamsNames, capacityUnitsNames, tasksNames, translations, uiMonday, uiTuesday, uiWednesday, uiThursday, uiFriday, uiSaturday, uiSunday, objectTypeName, slotSummary, legend, outsideRange, taskId, date, overrideSlotId
        .EXAMPLE
        PS> Get-JuribaCapacitySlot @DwParams -ProjectID 1
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$ProjectID
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = ("{0}/apiv1/admin/projects/{1}/capacitySlots" -f $Instance, $ProjectID) + '?$lang=en-US'

    try {
        $result = Invoke-WebRequest -Uri $uri -Headers $headers -Method GET
        return ($result.Content | ConvertFrom-Json).results
    }
    catch {
        Write-Error $_
    }
}