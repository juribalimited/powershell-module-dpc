function Get-JuribaTask {
    [alias("Get-DwTask")]
    <#
        .SYNOPSIS
        Returns existing Tasks.
        .DESCRIPTION
        Returns existing tasks using Dashworks API v2.
        .PARAMETER Instance
        Dashworks instance. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Dashworks API Key.
        .PARAMETER ProjectID
        Project ID to get project tasks from
        .OUTPUTS
        Project tasks objects
        id, name, help, stage, objectType, role, showDetailsAboutLastChangeNextToTask, hideCapacitySlotsOnSelfServiceWhenOnlyOneSlot, enabled, taskType, readOnly, languages, paths
        .EXAMPLE
        PS> Get-JuribaTask @dwparams -ProjectID 1
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory=$true)]
        [int]$ProjectID
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        # Get tasks info
        $uri = "{0}/apiv2/Projects/{1}/tasks" -f $instance, $ProjectID
        $headers = @{
            'x-api-key' = $ApiKey
        }
        try {
            $result = Invoke-WebRequest -Uri $uri -Headers $headers -Method GET        
            return ($result.Content | ConvertFrom-Json)
        }
        catch {
            Write-Error $_
        }
    }
    else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}