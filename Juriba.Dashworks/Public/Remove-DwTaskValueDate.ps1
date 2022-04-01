function Remove-DwTaskValueDate {
    <#
        .SYNOPSIS
        Clears a project date task.
        .DESCRIPTION
        Removes a the task value from a project date task.
        Takes TaskId, ProjectID, ObjectKey as inputs.
        .PARAMETER Instance
        Dashworks instance. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Dashworks API Key.
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
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
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
            $results = ($response.Content | ConvertFrom-Json).results
            return $results
        }
    }
    catch {
        Write-Error $_
    }
}
