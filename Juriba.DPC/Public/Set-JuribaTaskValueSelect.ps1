function Set-JuribaTaskValueSelect {
    [alias("Set-DwTaskValueSelect")]
    <#
        .SYNOPSIS
        Updates a project task.

        .DESCRIPTION
        Updates a project task.
        Takes TaskId OR TaskName, along with ProjectID, ObjectKey, and Value as inputs.

        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER TaskId
        TaskId of the task to be updated.

        .PARAMETER TaskName
        TaskName of the task to be updated.

        .PARAMETER ProjectId
        The projectId of the task being updated.

        .PARAMETER ObjectKey
        The ObjectKey (ComputerKey / Device Key / PackageKey) of the object being updated.

        .PARAMETER Value
        The value to set the task to.

        .PARAMETER ObjectType
        The type of object being updated.

        .EXAMPLE
        PS> Set-JuribaTaskValueSelect -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ObjectKey 12345 -ObjectType Device -TaskId 123 -ProjectId 85 -Value 6
    #>
    
    [CmdletBinding(DefaultParameterSetName = "ByTaskID", SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,

        [Parameter(Mandatory = $false)]
        [string]$APIKey,

        # Require TaskID if this parameter set is chosen
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTaskID')]
        [ValidateNotNullOrEmpty()]
        [int]$TaskId,

        # Require TaskName if this parameter set is chosen
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTaskName')]
        [ValidateNotNullOrEmpty()]
        [string]$TaskName,

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

        $uri = '{0}/apiv1/{1}/{2}/projectTasksValueRadioButton' -f $Instance, $path, $ObjectKey
        $headers = @{
            'x-api-key'    = $APIKey
            'content-type' = 'application/json'
        }

        # Get the task ID if the task name has been specified
        if ($PSCmdlet.ParameterSetName -eq 'ByTaskName') {
            $TaskID = Get-JuribaTask -ProjectID $ProjectID | Where-Object -Property name -EQ $TaskName | Select-Object -ExpandProperty id
        }

        $params = @{
            'value'     = $Value
            'projectid' = $ProjectID
            'taskid'    = $TaskID
        }

        $body = $params | ConvertTo-Json

        try {
            if ($PSCmdlet.ShouldProcess($ObjectKey)) {
                $response = Invoke-WebRequest -Uri $uri -Headers $headers -Body $body -Method PUT
                $results = $response.Content | ConvertFrom-Json
                return $results
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