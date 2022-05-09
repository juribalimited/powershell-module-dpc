Function New-DwAutomation {
    <#
    .SYNOPSIS

    Creates a new automation.

    .DESCRIPTION

    Creates a new automation using Dashworks API v1.

    .PARAMETER Instance

    Dashworks instance. For example, https://myinstance.dashworks.app:8443

    .PARAMETER APIKey

    Dashworks API Key.

    .PARAMETER Name

    Name of the new automation.

    .PARAMETER Description

    Description of the the automation.

    .PARAMETER ListId

    ListId for the automation scope.

    .PARAMETER IsActive

    Set the new automation to active or inactive. Defaults to True.

    .PARAMETER StopOnFailedAction

    Set the new value fo Stop on Failed Action. Defaults to False.

    .PARAMETER ObjectType

    Object type that this new automation applies to. One of Device, User, Application, Mailbox.

    .PARAMETER Schedule

    Schedule on which this automation should run. Accepts one of Manual, AfterTransform, Daily.

    .OUTPUTS

    AutomationId.

    .EXAMPLE

    PS> New-DwAutomation -Instance "https://myinstance.dashworks.app" -APIKey "xxxxx" -Name "My New Automation" -Description "Automation Description" -Active $true -StopOnFailedAction $false -ListId 123 -ObjectType Device -Schedule Manual

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Instance,
        [Parameter(Mandatory = $true)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [int]$ListId,
        [Parameter(Mandatory = $false)]
        [bool]$IsActive = $true,
        [Parameter(Mandatory = $false)]
        [bool]$StopOnFailedAction = $false,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox")]
        [string]$ObjectType,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Manual", "AfterTransform", "Daily")]
        [string]$Schedule
    )

    switch ($Schedule) {
        "Manual" {
            $scheduleTypeId = 1
            $sqlAgentJobName = $null
        }
        "AfterTransform" {
            $scheduleTypeId = 2
            $sqlAgentJobName = $null
        }
        "Daily" {
            $scheduleTypeId = 3
            $sqlAgentJobName = "Dashworks Daily"
        }
    }

    $objectTypeId = switch ($ObjectType) {
        "Device"        { 2 }
        "User"          { 1 }
        "Application"   { 3 }
        "Mailbox"       { 4 }
    }

    $payload  = @{}
    $payload.Add("id", -1)
    $payload.Add("name", $Name)
    $payload.Add("description", $Description)
    $payload.Add("isActive", $IsActive)
    $payload.Add("stopOnFailedAction", $StopOnFailedAction)
    $payload.Add("listId", $ListId)
    $payload.Add("objectTypeId", $objectTypeId)
    $payload.Add("scheduleTypeId", $scheduleTypeId)
    $payload.Add("sqlAgentJobName", $sqlAgentJobName)

    $jsonbody = $payload | ConvertTo-Json

    $uri = "{0}/apiv1/admin/automations" -f $Instance
    $headers = @{'x-api-key' = $APIKey }

    try {
        if ($PSCmdlet.ShouldProcess($Name)) {
            $result = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $jsonbody -ContentType 'application/json'
            if ($result.StatusCode -eq 201)
            {
                $id = ($result.content | ConvertFrom-Json).id
                return $id
            }
            else {
                throw "Error creating automation."
            }
        }
    }
    catch {
            Write-Error $_
    }
}
