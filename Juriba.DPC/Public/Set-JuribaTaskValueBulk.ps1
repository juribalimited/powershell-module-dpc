#requires -Version 7
function Set-JuribaTaskValueBulk {
    <#
        .SYNOPSIS
        Bulk updates a project task value across multiple objects.

        .DESCRIPTION
        Updates a single task value for multiple objects in one API call using the
        Juriba DPC API v1 bulk update endpoint. Supports select, date, and text task types.
        Returns an operation object with an opId that can be used with Get-JuribaTaskBulkUpdateLog
        to check the status of the bulk update.

        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ProjectId
        The project ID containing the task to be updated.

        .PARAMETER TaskId
        The ID of the task to be updated.

        .PARAMETER ObjectType
        The type of objects being updated. Device, User, Application, or Mailbox.

        .PARAMETER Objects
        An array of object keys to update.

        .PARAMETER SelectValue
        The select (radio button) value to set the task to.

        .PARAMETER DueDate
        Optional. An ISO 8601 formatted date string to set as the due date on a select task. e.g. '2026-04-15'

        .PARAMETER TeamId
        Optional. The team ID to assign on a select task. Can be used with or without OwnerId.

        .PARAMETER OwnerId
        Optional. The owner user ID (GUID) to assign on a select task. Requires TeamId.

        .PARAMETER DateValue
        An ISO 8601 formatted date string to set the date task to. e.g. '2026-04-15'

        .PARAMETER SlotId
        Optional. The capacity slot ID to set on a date task.

        .PARAMETER TextValue
        The text value to set the task to.

        .OUTPUTS
        An object containing opId, itemsCountSent, itemsCountAccepted, isEvergreen, and isServiceBrokerEnabled.

        .EXAMPLE
        PS> Set-JuribaTaskValueBulk -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -ProjectId 49 -TaskId 13188 -ObjectType Device -SelectValue 5 -Objects @(9141, 5123, 1)

        .EXAMPLE
        PS> Set-JuribaTaskValueBulk -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -ProjectId 49 -TaskId 13274 -ObjectType Device -SelectValue 1 -TeamId 2836 -OwnerId "971c8e3d-3c65-4e8e-b819-e1b4c8b1ed74" -Objects @(9141, 5123)

        .EXAMPLE
        PS> Set-JuribaTaskValueBulk -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -ProjectId 49 -TaskId 13265 -ObjectType Device -DateValue "2026-04-15" -SlotId 111 -Objects @(9141, 5123)

        .EXAMPLE
        PS> Set-JuribaTaskValueBulk -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -ProjectId 122 -TaskId 13760 -ObjectType Device -TextValue "Hello World" -Objects @(9141, 5123, 1)
    #>

    [CmdletBinding(DefaultParameterSetName = "Select", SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,

        [Parameter(Mandatory = $false)]
        [string]$APIKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$ProjectId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$TaskId,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox")]
        [string]$ObjectType,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int[]]$Objects,

        # Select parameter set
        [Parameter(Mandatory = $true, ParameterSetName = 'Select')]
        [ValidateNotNullOrEmpty()]
        [int]$SelectValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'Select')]
        [string]$DueDate,

        [Parameter(Mandatory = $false, ParameterSetName = 'Select')]
        [int]$TeamId,

        [Parameter(Mandatory = $false, ParameterSetName = 'Select')]
        [string]$OwnerId,

        # Date parameter set
        [Parameter(Mandatory = $true, ParameterSetName = 'Date')]
        [ValidateNotNullOrEmpty()]
        [string]$DateValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'Date')]
        [int]$SlotId,

        # Text parameter set
        [Parameter(Mandatory = $true, ParameterSetName = 'Text')]
        [ValidateNotNullOrEmpty()]
        [string]$TextValue
    )

    # Validate that OwnerId is not provided without TeamId
    if ($OwnerId -and -not $TeamId) {
        throw "OwnerId cannot be set without TeamId. Please provide a TeamId."
    }

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $path = switch ($ObjectType) {
            "Device"      { "devices" }
            "User"        { "users" }
            "Application" { "applications" }
            "Mailbox"     { "mailboxes" }
        }

        $uri = "{0}/apiv1/bulkupdate/{1}/{2}" -f $Instance, $path, $ProjectId
        $headers = @{
            'x-api-key'    = $APIKey
            'content-type' = 'application/json'
        }

        $body = @{
            'action' = 'taskUpdate'
            'taskId' = $TaskId
            'url'    = '/bulkupdate/{0}/{1}' -f $path, $ProjectId
            'items'  = @($Objects)
        }

        switch ($PSCmdlet.ParameterSetName) {
            'Select' {
                $body['setValue'] = $true
                $body['objectValue'] = $SelectValue

                if ($DueDate) {
                    $body['setDate'] = $true
                    $body['dateValue'] = $DueDate
                }

                if ($TeamId) {
                    $body['setOwner'] = $true
                    $body['updateBucketTeam'] = $true
                    $body['updateBucketOwner'] = $true
                    $body['assignedTeamId'] = $TeamId

                    if ($OwnerId) {
                        $body['assignedUserId'] = $OwnerId
                    }
                }
            }
            'Date' {
                $body['setDate'] = $true
                $body['dateValue'] = $DateValue

                if ($SlotId) {
                    $body['setSlot'] = $true
                    $body['capacitySlotId'] = $SlotId
                } else {
                    $body['setSlot'] = $false
                }
            }
            'Text' {
                $body['setValue'] = $true
                $body['objectValue'] = $TextValue
            }
        }

        $jsonBody = $body | ConvertTo-Json
        $encodedBody = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)

        try {
            if ($PSCmdlet.ShouldProcess("TaskId: $TaskId, Objects: $($Objects.Count)")) {
                $response = Invoke-WebRequest -Uri $uri -Headers $headers -Body $encodedBody -Method PATCH
                $result = $response.Content | ConvertFrom-Json
                return $result
            }
        }
        catch {
            Write-Error $_
        }
    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
