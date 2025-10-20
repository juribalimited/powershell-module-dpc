function Set-JuribaAutomationAction {
    [alias("Set-DwAutomationAction")]
    <#
        .SYNOPSIS
        Updates an automation action.
        .DESCRIPTION
        Updates an automation action using Dashworks API v1.
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ActionId
        ActionId for the action.
        .PARAMETER Name
        Name of the automation action.
        .PARAMETER AutomationId
        AutomationId for the action.
        .PARAMETER TypeId
        TypeId for the action
        .PARAMETER ProjectId
        ProjectId for the action.
        .PARAMETER IsEvergreen
        IsEvergreen flag for the action.
        .PARAMETER Parameter
        Gets the object of the type from the set structure
        .OUTPUTS
        ActionId.
        .EXAMPLE
        PS> Set-JuribaAutomationAction -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ActionId 10 -Name "Update Custom Field Value" -AutomationId 1 -TypeId 1 -ProjectId 1 -IsEvergreen $false
            -Parameter 'parameters=@(@{property="TaskId";value=11;meta="task"};@{property="Value";value=2;meta="Radiobutton"};@{property="ValueActionType";value=1;meta="Radiobutton"};)'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$ActionId,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [int]$AutomationId,
        [Parameter(Mandatory = $true)]
        [int]$TypeId,
        [Parameter(Mandatory = $true)]
        [int]$ProjectId,
        [Parameter(Mandatory = $false)]
        [bool]$IsEvergreen = $false,
        [Parameter(Mandatory = $true)]
        [Object]$Parameters
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $payload = @{}
        $payload.Add("id", $ActionId)
        $payload.Add("name", $Name)
        $payload.Add("typeId", $TypeId)
        $payload.Add("projectId", $ProjectId)
        $payload.Add("isEvergreen", $IsEvergreen)
        
        if($Parameters) {
            $list = New-Object System.Collections.ArrayList
            $list = $Parameters
            $payload.Add("parameters", [Array]$list)
        }
    
        $jsonbody = $payload | ConvertTo-Json -Depth 6    
        $uri = "{0}/apiv1/admin/automations/{1}/actions/{2}" -f $Instance, $AutomationId, $ActionId
        $headers = @{'x-api-key' = $APIKey }
    
        try {
            if ($PSCmdlet.ShouldProcess($Name)) {
                $result = Invoke-WebRequest -Uri $uri -Method PUT -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType 'application/json'
                if ($result.StatusCode -eq 200) {
                    $id = ($result.content | ConvertFrom-Json).id
                    return $id
                }
                else {
                    throw "Error updating automation action."
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