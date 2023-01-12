function Remove-DwTaskValueDate {
    <#
        .SYNOPSIS
        Clears a project date task.
        .DESCRIPTION
        Removes a the task value from a project date task.
        Takes TaskId, ProjectID, ObjectKey as inputs.
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Dw. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Dw.
        .PARAMETER TaskId
        TaskId of the task to have its value removed.
        .PARAMETER ProjectId
        The projectId of the task being updated.
        .PARAMETER ObjectKey
        The projectId of the task being updated.
        .PARAMETER ObjectType
        The type of object being updated.

        .EXAMPLE
        PS> Remove-DwTaskValueDate -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ObjectKey 12345 -ObjectType Device -TaskId 123 -ProjectId 85
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
    
        $uri = '{0}/apiv1/{1}/{2}/removeTasksDateAndSlot' -f $Instance, $path, $ObjectKey
        $headers = @{
            'x-api-key' = $APIKey
            'content-type' = 'application/Json'
            }
    
        $params = @{
            'projectid' = $ProjectID
            'taskid' = $TaskID
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
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Dw before proceeding."
    }
}
