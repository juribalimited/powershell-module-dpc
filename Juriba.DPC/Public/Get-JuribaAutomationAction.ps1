function Get-JuribaAutomationAction {
    [alias("Get-DwAutomationAction")]
    <#
        .SYNOPSIS
        Returns existing automation actions from the automation id.
        .DESCRIPTION
        Returns existing automation actions using Dashworks API v1.
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER AutomationId
        AutomationId for the automation to return the actions for
        .OUTPUTS
        Automation action object
        id, name, processingOrder, typeId, typeName, projectId, projectName, taskFields, updateType, values, automationId
        .EXAMPLE
        PS> Get-JuribaAutomationAction -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -AutomationId 1
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$AutomationId
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $uri = ("{0}/apiv1/admin/automations/{1}/actions" -f $Instance, $AutomationId) + '?$lang=en-US'
        $headers = @{'x-api-key' = $APIKey }
    
        try {
            $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType 'application/json'
            return (($result.content | ConvertFrom-Json ).results)
        }
        catch {
            Write-Error $_
        }
    }
    else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}