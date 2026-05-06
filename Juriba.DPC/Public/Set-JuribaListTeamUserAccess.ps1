Function Set-JuribaListTeamUserAccess {
    <#
        .SYNOPSIS
        Updates an existing list with Team Access.

        .DESCRIPTION
        Uses ApiV1 to update an existing list with Team Access.

        .PARAMETER Instance

        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.juriba.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ObjectType

        Base object type for the new list. Accepts one of: "Device", "User", "Application", "Mailbox", "ApplicationUser", "ApplicationDevice"

        .PARAMETER AccessType

        Sets the Team Access permissions for the list. Accepts one of: "ReadOnly", "Edit", "Admin". Optional, if ommited "Edit" is used.

        .PARAMETER UserTeam

        Sets the type of User / Team to be set up. Accepts one of: "Team", "User".

        .PARAMETER ListID

        Used in the Header to find the Lsit to update Team permissions.

        .PARAMETER TeamID

        Sets the TeamID for the Team for Access to be set fro the list.

        .EXAMPLE

        PS> Set-JuribaListTeamUserAccess
            -Instance "https://myinstance.juriba.app:8443"
            -APIKey "xxxxx"
            -ObjectType "Device"
            -AccessType "Admin"
            -UserTeam "User"
            -ListID 1234
            -TeamID 3
            -UserId "xxxxxxxxx"

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [string]$ObjectType,
        [Parameter(Mandatory = $false)]
        [ValidateSet("ReadOnly", "Admin", "Edit")]
        [string]$AccessType = "Edit",
        [Parameter(Mandatory = $true)]
        [ValidateSet("Team", "User")]
        [string]$UserTeam,
        [Parameter(Mandatory = $true)]
        [string]$ListID,
        [Parameter(Mandatory = $false)]
        [string]$Teamid,
        [Parameter(Mandatory = $false)]
        [string]$Userid
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
            "User" { $endpoint = "users "}
            "Application" { $endpoint = "applications" }
            "Mailbox" { $endpoint = "mailboxes" }
        }

        $body = @{
            "userid"     = $Userid
            "teamID"     = $TeamId
            "accessType" = $AccessType
        } | ConvertTo-Json

        $contentType = "application/json"
        $headers = @{ 'X-API-KEY' = $ApiKey }
        $uri = "{0}/apiv1/lists/{1}/{2}/{3}"  -f  $instance, $endpoint, $listid, $userteam

        if ($PSCmdlet.ShouldProcess($TeamId)) {
            $result = Invoke-WebRequest -Uri $uri -Headers $headers -Body $body -Method POST -ContentType $contentType

            return ($result.content | ConvertFrom-Json)
        }
    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
