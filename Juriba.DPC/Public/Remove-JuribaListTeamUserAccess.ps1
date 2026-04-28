#requires -Version 7
function Remove-JuribaListTeamUserAccess {
    <#
        .SYNOPSIS
        Revokes a user or team's access to a list.

        .DESCRIPTION
        Uses ApiV1 to delete a previously-granted user or team access record from
        a list. Pair with Set-JuribaListTeamUserAccess (which adds grants) and
        Set-JuribaListAccessType (which controls the list's overall access mode).

        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ObjectType
        Base object type for the list. Accepts one of: "Device", "User", "Application", "Mailbox", "ApplicationUser", "ApplicationDevice"

        .PARAMETER ListId
        The id of the list whose grant is being removed.

        .PARAMETER UserId
        The id of the user whose access should be revoked. Mutually exclusive with -TeamId.

        .PARAMETER TeamId
        The id of the team whose access should be revoked. Mutually exclusive with -UserId.

        .OUTPUTS
        The API response from the DELETE call (typically the string "Delete success").

        .EXAMPLE
        PS> Remove-JuribaListTeamUserAccess -ObjectType Device -ListId 1234 -UserId "abc-123-..."

        .EXAMPLE
        PS> Remove-JuribaListTeamUserAccess -ObjectType Device -ListId 1234 -TeamId "5"
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName='User')]
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
        [Parameter(Mandatory=$true, ParameterSetName='User')]
        [string]$UserId,
        [Parameter(Mandatory=$true, ParameterSetName='Team')]
        [string]$TeamId
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $endpoint = ""
        switch ($ObjectType) {
            "ApplicationUser"   { throw "not implemented" }
            "ApplicationDevice" { throw "not implemented" }
            "Device"            { $endpoint = "devices" }
            "User"              { $endpoint = "users " }
            "Application"       { $endpoint = "applications" }
            "Mailbox"           { $endpoint = "mailboxes" }
        }

        if ($PSCmdlet.ParameterSetName -eq 'User') {
            $target = "user"
            $targetId = $UserId
        } else {
            $target = "team"
            $targetId = $TeamId
        }

        $headers = @{ 'X-API-KEY' = $APIKey }
        $uri = "{0}/apiv1/lists/{1}/{2}/{3}/{4}" -f $Instance, $endpoint, $ListId, $target, $targetId

        try {
            if ($PSCmdlet.ShouldProcess($targetId)) {
                $result = Invoke-RestMethod -Uri $uri -Method DELETE -Headers $headers
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
