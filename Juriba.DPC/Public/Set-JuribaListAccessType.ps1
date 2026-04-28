#requires -Version 7
function Set-JuribaListAccessType {
    <#
        .SYNOPSIS
        Updates the View, Edit and Administer access type of an existing list.

        .DESCRIPTION
        Uses ApiV1 to update the sharedReadAccessType, sharedEditAccessType and
        sharedAdministerAccessType fields of an existing list. The endpoint requires
        the full list payload, so this function fetches the current state, applies
        only the access types supplied by the caller, and PUTs the result back.

        The DPC API enforces a permissiveness hierarchy: View must be at least as
        permissive as Edit, and Edit at least as permissive as Administer
        (Owner < SpecificUserTeam < Everyone). Violating this returns a generic
        validation error from the server, so this function validates client-side
        and throws a descriptive error before sending.

        Setting an access type to "SpecificUserTeam" creates a list configured to
        accept specific user/team grants but does not assign any. Use
        Set-JuribaListTeamUserAccess to grant access to a user or team after
        changing the access type.

        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ObjectType
        Base object type for the list. Accepts one of: "Device", "User", "Application", "Mailbox", "ApplicationUser", "ApplicationDevice"

        .PARAMETER ListId
        The id of the list to update.

        .PARAMETER ViewAccessType
        Optional. Sets the View access permission. Accepts one of: "Owner", "Everyone", "SpecificUserTeam".

        .PARAMETER EditAccessType
        Optional. Sets the Edit access permission. Accepts one of: "Owner", "Everyone", "SpecificUserTeam".

        .PARAMETER AdminAccessType
        Optional. Sets the Administer access permission. Accepts one of: "Owner", "Everyone", "SpecificUserTeam".

        .OUTPUTS
        The API response from the PUT call (typically the string "Update success").

        .EXAMPLE
        PS> Set-JuribaListAccessType -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxx" `
                -ObjectType Device -ListId 1234 -ViewAccessType SpecificUserTeam

        .EXAMPLE
        PS> Set-JuribaListAccessType -ObjectType Device -ListId 1234 `
                -ViewAccessType SpecificUserTeam -EditAccessType SpecificUserTeam
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([String])]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Device", "User", "Application", "Mailbox", "ApplicationUser", "ApplicationDevice")]
        [string]$ObjectType,
        [Parameter(Mandatory=$true)]
        [int]$ListId,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Owner", "Everyone", "SpecificUserTeam")]
        [string]$ViewAccessType,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Owner", "Everyone", "SpecificUserTeam")]
        [string]$EditAccessType,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Owner", "Everyone", "SpecificUserTeam")]
        [string]$AdminAccessType
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        if (-not ($ViewAccessType -or $EditAccessType -or $AdminAccessType)) {
            throw "At least one of -ViewAccessType, -EditAccessType or -AdminAccessType must be specified."
        }

        $endpoint = ""
        switch ($ObjectType) {
            "ApplicationUser"   { throw "not implemented" }
            "ApplicationDevice" { throw "not implemented" }
            "Device"            { $endpoint = "devices" }
            "User"              { $endpoint = "users " }
            "Application"       { $endpoint = "applications" }
            "Mailbox"           { $endpoint = "mailboxes" }
        }

        $headers = @{ 'X-API-KEY' = $APIKey }
        $uri = "{0}/apiv1/lists/{1}/{2}" -f $Instance, $endpoint, $ListId

        try {
            $current = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
        }
        catch {
            Write-Error ("Failed to fetch list {0}: {1}" -f $ListId, $_)
            return
        }

        $newView  = if ($ViewAccessType)  { $ViewAccessType }  else { $current.sharedReadAccessType }
        $newEdit  = if ($EditAccessType)  { $EditAccessType }  else { $current.sharedEditAccessType }
        $newAdmin = if ($AdminAccessType) { $AdminAccessType } else { $current.sharedAdministerAccessType }

        # Owner < SpecificUserTeam < Everyone in permissiveness; the API rejects
        # configurations where Edit is more permissive than View, or Admin than Edit.
        $rank = @{ 'Owner' = 1; 'SpecificUserTeam' = 5; 'Everyone' = 6 }
        if ($rank[$newEdit] -gt $rank[$newView]) {
            throw "Edit access ($newEdit) cannot be more permissive than View access ($newView). The DPC API requires View >= Edit >= Administer."
        }
        if ($rank[$newAdmin] -gt $rank[$newEdit]) {
            throw "Administer access ($newAdmin) cannot be more permissive than Edit access ($newEdit). The DPC API requires View >= Edit >= Administer."
        }

        $body = @{
            listId                     = $current.listId
            listName                   = $current.listName
            listDescription            = $current.listDescription
            listType                   = $current.listType
            queryString                = $current.queryString
            sharedReadAccessType       = $newView
            sharedEditAccessType       = $newEdit
            sharedAdministerAccessType = $newAdmin
            userId                     = $current.userId
            cachedKeySetId             = $current.cachedKeySetId
        } | ConvertTo-Json

        try {
            if ($PSCmdlet.ShouldProcess("List $ListId")) {
                $result = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers `
                    -ContentType "application/json" -Body $body
                return $result
            }
        }
        catch {
            Write-Error $_
        }
    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
