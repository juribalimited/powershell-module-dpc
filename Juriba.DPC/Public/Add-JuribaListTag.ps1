Function Add-JuribaListTag {
    <#
    .SYNOPSIS

    Adds an existing tag to a list.

    .DESCRIPTION

    Adds an existing tag to a list using Dashworks API v1.

    .PARAMETER Instance

    Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

    .PARAMETER APIKey

    Optional. API key to be provided if not authenticating using Connect-Juriba.

    .PARAMETER ObjectType

    Object type of the list. Accepts one of: "Device", "User", "Application", "Mailbox". "ApplicationUser" and "ApplicationDevice" are accepted but not implemented.

    .PARAMETER ListId

    Id of the list to add the tag to.

    .PARAMETER Tag

    Name of an existing tag to add to the list. Use New-JuribaTag to create a tag first.

    .EXAMPLE

    PS> Add-JuribaListTag -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -ObjectType "Device" -ListId 123 -Tag "W11 Pilot"

    #>
    [alias("Add-DwListTag")]

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox", "ApplicationUser", "ApplicationDevice")]
        [string]$ObjectType,
        [Parameter(Mandatory = $true)]
        [int]$ListId,
        [Parameter(Mandatory = $true)]
        [string]$Tag
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $endpoint = ""
        switch ($ObjectType) {
            "ApplicationUser" { throw "not implemented" }
            "ApplicationDevice" { throw "not implemented" }
            "Device" { $endpoint = "devices" }
            "User" { $endpoint = "users" }
            "Application" { $endpoint = "applications" }
            "Mailbox" { $endpoint = "mailboxes" }
        }
    
        $body = @{
            tag = $Tag
        } | ConvertTo-Json
    
        $uri = "{0}/apiv1/lists/{1}/{2}/tag" -f $Instance, $endpoint, $ListId
        $headers = @{ 'x-api-key' = $APIKey }
    
        try {
            if ($PSCmdlet.ShouldProcess($Tag)) {
                Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $body -ContentType 'application/json'
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
