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
        PS> Set-DwTaskValueDate -Instance $APIServer -APIKey $APIKey -ObjectKey 12345 -ObjectType Device -TaskId 123 -ProjectId 85 -Value '2022-01-01' -SlotId 34
    #>

    [CmdletBinding()]
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

    $Params = @{
        'projectid'=$ProjectID
        'taskid'=$TaskID
        }


    $Body = $Params | ConvertTo-Json

    try {
        $response = Invoke-WebRequest -uri $uri -Headers $headers -Body $Body -Method PUT
        $results = ($response.Content | ConvertFrom-Json).results
        retrn $results
    }
    catch {
        Write-Error $_
    }
}