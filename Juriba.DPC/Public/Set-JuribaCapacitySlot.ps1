function Set-JuribaCapacitySlot {
    [alias("Set-DwCapacitySlot")]
    <#
        .SYNOPSIS
        Create a new capacity slot
        .DESCRIPTION
        Create a new capacity slot using API v1
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ProjectID
        ID of the project
        .PARAMETER SlotID
        Id of the slot to modify
        .PARAMETER SlotName
        Name of the slot
        .PARAMETER DisplayName
        Display name of the slot
        .PARAMETER AllRequestTypes
        Defaults to false
        .PARAMETER AllTeams
        Defaults to false
        .PARAMETER AllUnits
        Defaults to false
        .PARAMETER CapacityType
        The capacity type to be used, either Teams & Request Types, Capacity Units
        .PARAMETER ObjectType
        Object type that this new automation applies to. One of Device, User, Application, Mailbox.
        .PARAMETER TranslationsObject
        Translation related information, retrieve from the database
        .PARAMETER SlotAvailableFrom
        Start date of when slot will be available from
        .PARAMETER SlotAvailableTo
        Start date of when slot will be available to
        .PARAMETER SlotStartTime
        Start time of the slot availability
        .PARAMETER SlotEndTime
        End time of the slot availability
        .PARAMETER Monday
        The maximum number of slot for the day, -1 is unlimited
        .PARAMETER Tuesday
        The maximum number of slot for the day, -1 is unlimited
        .PARAMETER Wednesday
        The maximum number of slot for the day, -1 is unlimited
        .PARAMETER Thursday
        The maximum number of slot for the day, -1 is unlimited
        .PARAMETER Friday
        The maximum number of slot for the day, -1 is unlimited
        .PARAMETER Saturday
        The maximum number of slot for the day, -1 is unlimited
        .PARAMETER Sunday
        The maximum number of slot for the day, -1 is unlimited
        .PARAMETER RequestTypes
        The id/s of the request types to apply
        .PARAMETER Teams
        The id/s of the teams to apply
        .PARAMETER Tasks
        The id/s of the tasks to apply
        .PARAMETER Units
        The id/s of the units to apply
        .OUTPUTS
        The capacity slot details have been updated
        .EXAMPLE
        PS> Set-JuribaCapacityUnit -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ProjectID 1 -SlotID 1 -SlotName "W11 Deployment Slot" -DisplayName "Mon - Fri" -CapacityType "Capacity Units" 
            -ObjectType "Device" -TranslationsObject '[{\"languageId\":0,\"language\":\"English\",\"translatedString\":\"Mon - Fri\",\"isTranslated\":true,\"isDefault\":true}]' -SlotAvailableFrom $null 
            -SlotAvailableTo $null -SlotStartTime "" -SlotEndTime "" -Monday 50 -Tuesday 50 -Wednesday 50 -Thursday 50 -Friday 50 -Saturday 0 -Sunday 0 -RequestTypes "" -Teams "" -Tasks 17 -Units 2
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$ProjectID,
        [Parameter(Mandatory = $true)]
        [int]$SlotID,
        [Parameter(Mandatory = $true)]
        [string]$SlotName,
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        [Parameter(Mandatory = $false)]
        [bool]$AllRequestTypes = $false,
        [Parameter(Mandatory = $false)]
        [bool]$AllTeams = $false,
        [Parameter(Mandatory = $false)]
        [bool]$AllUnits = $false,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Teams & Request Types","Capacity Units")]
        [string]$CapacityType,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox")]
        [string]$ObjectType,
        [Parameter(Mandatory = $false)]
        [string]$TranslationsObject,
        [Parameter(Mandatory = $false)]
        [string]$SlotAvailableFrom = $null,
        [Parameter(Mandatory = $false)]
        [string]$SlotAvailableTo = $null,
        [Parameter(Mandatory = $false)]
        [string]$SlotStartTime = $null,
        [Parameter(Mandatory = $false)]
        [string]$SlotEndTime = $null,
        [Parameter(Mandatory = $false)]
        [string]$Monday,
        [Parameter(Mandatory = $false)]
        [string]$Tuesday,
        [Parameter(Mandatory = $false)]
        [string]$Wednesday,
        [Parameter(Mandatory = $false)]
        [string]$Thursday,
        [Parameter(Mandatory = $false)]
        [string]$Friday,
        [Parameter(Mandatory = $false)]
        [string]$Saturday,
        [Parameter(Mandatory = $false)]
        [string]$Sunday,
        [Parameter(Mandatory = $false)]
        [string]$RequestTypes,
        [Parameter(Mandatory = $false)]
        [string]$Teams,
        [Parameter(Mandatory = $false)]
        [string]$Tasks,
        [Parameter(Mandatory = $false)]
        [string]$Units
    )

    $CapacityTypeId = switch ($CapacityType) {
        "Teams & Request Types"  { 1 }
        "Capacity Units" { 2 }
    }

    $objectTypeId = switch ($ObjectType) {
        "Device"        { 2 }
        "User"          { 1 }
        "Application"   { 3 }
        "Mailbox"       { 4 }
    }

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $payload = @{
            "slotId" = $SlotID
            "slotName" = $SlotName
            "displayName" = $DisplayName
            "allRequestTypes" = $AllRequestTypes
            "allTeams" = $AllTeams
            "allUnits" = $AllUnits
            "capacityType" = $CapacityTypeId
            "objectType" = $objectTypeId
            "translationsObject" = $TranslationsObject
            "monday" = $Monday
            "tuesday" = $Tuesday
            "wednesday" = $Wednesday
            "thursday" = $Thursday
            "friday" = $Friday
            "saturday" = $Saturday
            "sunday" = $Sunday
            "requestTypes" = $RequestTypes
            "teams" = $Teams
            "tasks" = $Tasks
            "units" = $Units
        }
        
        if ($null -ne $SlotAvailableFrom -and $SlotAvailableFrom -ne "") { 
            $payload.Add("slotAvailableFrom", $SlotAvailableFrom)
        }
        if ($null -ne $SlotAvailableTo -and $SlotAvailableTo -ne "") { 
            $payload.Add("slotAvailableTo", $SlotAvailableTo)
        }
        if ($null -ne $SlotStartTime) { 
            $payload.Add("slotStartTime", $SlotStartTime)
        }
        if ($null -ne $SlotEndTime) { 
            $payload.Add("slotEndTime", $SlotEndTime)
        }
    
        $jsonbody = ($payload | ConvertTo-Json).Replace("\\\", "\")

        $contentType = "application/json"
        $headers = @{ 'X-API-KEY' = $ApiKey }
        $uri = "{0}/apiv1/admin/projects/{1}/updateCapacitySlot" -f $Instance, $ProjectID
    
        if ($PSCmdlet.ShouldProcess($SlotName)) {
            $result = Invoke-WebRequest -Uri $uri -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -Method PUT -ContentType $contentType
            return ($result.Content | ConvertFrom-Json).message
        }
    }
    else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}