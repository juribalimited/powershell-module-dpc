function Set-JuribaAutomation {
    [alias("Set-DwAutomation")]
    <#
        .SYNOPSIS
        Updates an automation.
        .DESCRIPTION
        Updates an automation using Dashworks API v1.
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER AutomationId    
        Id of the automation    
        .PARAMETER Name
        Name of the automation.
        .PARAMETER Description
        Description of the the automation.
        .PARAMETER ListId
        ListId for the automation scope.
        .PARAMETER IsActive
        Set the new automation to active or inactive. Defaults to True.
        .PARAMETER StopOnFailedAction
        Set the value of Stop on Failed Action. Defaults to False.
        .PARAMETER ObjectType
        Object type that this new automation applies to. One of Device, User, Application, Mailbox.
        .PARAMETER Schedule
        Schedule on which this automation should run. Accepts one of Manual, AfterTransform, Daily.
        .OUTPUTS
        AutomationId.
        .EXAMPLE
        PS> Set-JuribaAutomation -Instance "https://myinstance.dashworks.app" -APIKey "xxxxx" -AutomationId 1 -Name "My Automation" -Description "Automation Description" -ListId 123 -IsActive $true -StopOnFailedAction $false -ObjectType Device -Schedule Manual
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$AutomationId,
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

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
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
    
        $payload = @{}
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
    
        $uri = "{0}/apiv1/admin/automations/{1}" -f $Instance, $AutomationId
        $headers = @{'x-api-key' = $APIKey }
    
        try {
            if ($PSCmdlet.ShouldProcess($Name)) {
                $result = Invoke-WebRequest -Uri $uri -Method PUT -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType 'application/json'
                if ($result.StatusCode -eq 200)
                {
                    $id = ($result.content | ConvertFrom-Json).id
                    return $id
                }
                else {
                    throw "Error updating automation."
                }
            }
        }
        catch {
            Write-Error $_
        }
    }
    else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}