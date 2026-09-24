#requires -Version 7
function Get-JuribaProjectCategory {
    <#
        .SYNOPSIS
        Returns categories for a specified project and object type.
        .DESCRIPTION
        Returns categories for a project using Juriba DPC API v1.
        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ProjectID
        ID of the project to return categories for.
        .PARAMETER ObjectType
        The type of object the categories apply to. Valid values are Device, User, Application, Mailbox.
        .OUTPUTS
        Category objects
        id, name
        .EXAMPLE
        PS> Get-JuribaProjectCategory -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxx" -ProjectID 49 -ObjectType Device
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$ProjectID,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox")]
        [string]$ObjectType
    )
 
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }
 
    if ($APIKey -and $Instance) {
        $objectTypeId = switch ($ObjectType) {
            "User" { 1 }
            "Device" { 2 }
            "Application" { 3 }
            "Mailbox" { 4 }
        }
 
        $uri = "{0}/apiv1/categories?projectId={1}&objectTypeId={2}" -f $Instance, $ProjectID, $objectTypeId
        $headers = @{ 'x-api-key' = $APIKey }
 
        try {
            $result = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers'application/json'
            return $result
        }
        catch {
            Write-Error $_
        }
    }
    else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}