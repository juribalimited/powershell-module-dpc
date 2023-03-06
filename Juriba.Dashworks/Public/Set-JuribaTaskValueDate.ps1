function Set-JuribaTaskValueDate {
    [alias("Set-DwTaskValueDate")]
    <#
        .SYNOPSIS
        Updates a project date task.
        .DESCRIPTION
        Updates a project task. This cannot be used to clear the date value.
        Takes TaskId, ProjectID, ObjectKey, Value and SlotId (optional) as inputs.
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER TaskId
        TaskId of the task to be updated.
        .PARAMETER ProjectId
        The projectId of the task being updated.
        .PARAMETER ObjectKey
        The projectId of the task being updated.
        .PARAMETER Value
        An ISO 8601 formatted date string to set the task to. EG ('2022-01-01')
        .PARAMETER SlotId
        Optional: The slot to set the task to. The slotId is not validated.
        .PARAMETER ObjectType
        The type of object being updated.

        .EXAMPLE
        PS> Set-JuribaTaskValueDate -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ObjectKey 12345 -ObjectType Device -TaskId 123 -ProjectId 85 -Value '2022-01-01' -SlotId 34
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$TaskId,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$ProjectId,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$ObjectKey,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value,
        [Parameter(Mandatory = $false)]
        [string]$SlotId,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox")]
        [string]$ObjectType
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $path = switch($ObjectType) {
            "Device"        {"device"}
            "User"          {"user"}
            "Application"   {"application"}
            "Mailbox"       {"mailbox"}
        }
    
        $uri = '{0}/apiv1/{1}/{2}/projectTasksDateAndSlot' -f $Instance, $path, $ObjectKey
        $headers = @{
            'x-api-key' = $APIKey
            'content-type' = 'application/Json'
            }
    
    
        $params = @{
            'date'=$Value
            'projectid'=$ProjectID
            'taskid'=$TaskID
            }
    
        if ($SlotId)
        {
            $params.add("slotid",$SlotID)
        }
    
        $body = $params | ConvertTo-Json
    
        try {
            if ($PSCmdlet.ShouldProcess($ObjectKey)) {
                $response = Invoke-WebRequest -Uri $uri -Headers $headers -Body $body -Method PUT
                $results = ($response.Content | ConvertFrom-Json).message
                return $results
            }
        }
        catch {
            Write-Error $_
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
