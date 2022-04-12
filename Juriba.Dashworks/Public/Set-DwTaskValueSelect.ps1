function Set-DwTaskValueSelect {
    <#
        .SYNOPSIS
        Updates a project task.
        .DESCRIPTION
        Updates a project task.
        Takes TaskId, ProjectID and ObjectKey and Value as inputs.
        .PARAMETER Instance
        Dashworks instance. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Dashworks API Key.
        .PARAMETER TaskId
        TaskId of the task to be updated.
        .PARAMETER ProjectId
        The projectId of the task being updated.
        .PARAMETER ObjectKey
        The ObjectKey (ComputerKey / Device Key / PackageKey) of the object being updated.
        .PARAMETER Value
        The value to set the task to.
        .PARAMETER ObjectType
        The type of object being updated.

        .EXAMPLE
        PS> Set-DwTaskValueSelect -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ObjectKey 12345 -ObjectType Device -TaskId 123 -ProjectId 85 -Value 6
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
        [ValidateNotNullOrEmpty()]
        [int]$Value,
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

    $uri = '{0}/apiv1/{1}/{2}/projectTasksValueRadioButton' -f $Instance, $path, $ObjectKey
    $headers = @{
        'x-api-key' = $APIKey
        'content-type' = 'application/Json'
        }


    $params = @{
        'value' = $Value
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
}
