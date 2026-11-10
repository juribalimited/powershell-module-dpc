Function Remove-JuribaList {
    <#
        .SYNOPSIS
        Deletes a list.

        .DESCRIPTION
        Deletes a device, user, application or mailbox list in Juriba DPC using API v1.

        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ObjectType
        Object type of the list. One of Device, User, Application or Mailbox. ApplicationUser and ApplicationDevice are accepted but not yet implemented, and throw an error.

        .PARAMETER ListId
        Id of the list to delete.

        .OUTPUTS
        The web response from the API call.

        .EXAMPLE
        PS> Remove-JuribaList -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -ObjectType Device -ListId 42
    #>
    [alias("Remove-DwList")]
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox", "ApplicationUser", "ApplicationDevice")]
        [string]$ObjectType,
        [Parameter(Mandatory=$true)]
        [int]$ListId
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
            "Device" { $endpoint = "devices"}
            "User" { $endpoint = "users"}
            "Application" { $endpoint = "applications" }
            "Mailbox" { $endpoint = "mailboxes" }
        }
    
        $headers = @{ 'X-API-KEY' = $ApiKey }
        $uri = "{0}/apiv1/lists/{1}/{2}"  -f  $instance, $endpoint, $ListId
    
        if ($PSCmdlet.ShouldProcess($ListId)) {
            Invoke-WebRequest -Uri $uri -Headers $headers -Method DELETE
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}