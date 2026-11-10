Function Remove-JuribaAutomation {
    <#
    .SYNOPSIS

    Deletes an automation.

    .DESCRIPTION

    Deletes an automation using Dashworks API v1.

    .PARAMETER Instance

    Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

    .PARAMETER APIKey

    Optional. API key to be provided if not authenticating using Connect-Juriba.

    .PARAMETER AutomationId

    Id of the automation to delete.

    .EXAMPLE

    PS> Remove-JuribaAutomation -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -AutomationId 5

    #>
    [alias("Remove-DwAutomation")]

    [CmdletBinding(SupportsShouldProcess)]
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
        $body = @{
            automationIds = @($AutomationId)
        } | ConvertTo-Json
    
        $uri = "{0}/apiv1/admin/automations" -f $Instance
        $headers = @{'x-api-key' = $APIKey }
    
        if ($PSCmdlet.ShouldProcess($AutomationId)) {
            Invoke-WebRequest -Uri $uri -Method DELETE -Body $body -Headers $headers -ContentType 'application/json'
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}