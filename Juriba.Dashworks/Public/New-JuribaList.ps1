Function New-JuribaList {
    [alias("New-DwList")]
    <#
        .SYNOPSIS
        Creates a new list.

        .DESCRIPTION
        Uses ApiV1 to create a new list.

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER Name

        Name for the new list.

        .PARAMETER UserId

        UserId for the user who will own this list. See Get-JuribaSessionUser.

        .PARAMETER ListType

        The type of list to create. Accepts one of: "Dynamic", "Static" or "Dynamic Pivot"

        .PARAMETER QueryString

        The query string for the new list. The easiest way to generate this is to create the list you want in the UI then, using broswer
        dev tools, capture the POST request when saving the list. Use the QueryString property from the captured request payload.
        Note that $ characters may need escaping if PowerShell interprets them as variables.

        .PARAMETER ObjectType

        Base object type for the new list. Accepts one of: "Device", "User", "Application", "Mailbox", "ApplicationUser", "ApplciationDevice"

        .PARAMETER SharedViewAccessType

        Sets the View Access permissions for the list. Accepts one of: "Owner", "Eveyone". Optional, if ommited "Owner" is used.

        .PARAMETER SharedEditAccessType

        Sets the Edit Access permissions for the list. Accepts one of: "Owner", "Eveyone". Optional, if ommited "Owner" is used.

        .PARAMETER SharedAdminAccessType

        Sets the Admin Access permissions for the list. Accepts one of: "Owner", "Eveyone". Optional, if ommited "Owner" is used.

        .EXAMPLE

        PS> New-JuribaList
            -Instance "https://myinstance.dashworks.app:8443"
            -APIKey "xxxxx"
            -Name "My New List"
            -UserId ((Get-JuribaSessionUser).userId)
            -ListType Dynamic
            -QueryString "`$filter=&`$select=hostname,chassisCategory,oSCategory,ownerDisplayName,bootupDate&`$pinleft=&`$pinright=&`$archiveditems=false"
            -ObjectType "Device"
            -SharedViewAccessType "Everyone"
            -SharedEditAccessType "Owner"
            -SharedAdminAccessType "Owner"


    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [guid]$UserId,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Dynamic", "Static", "Dynamic Pivot")]
        [string]$ListType,
        [Parameter(Mandatory = $true)]
        [string]$QueryString,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox", "ApplicationUser", "ApplciationDevice")]
        [string]$ObjectType,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Owner", "Everyone")]
        [string]$SharedViewAccessType = "Owner",
        [Parameter(Mandatory = $false)]
        [ValidateSet("Owner", "Everyone")]
        [string]$SharedEditAccessType = "Owner",
        [Parameter(Mandatory = $false)]
        [ValidateSet("Owner", "Everyone")]
        [string]$SharedAdminAccessType = "Owner"
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

        switch ($ListType) {
            "Static" { throw "not implemented" }
        }

        $body = @{
            "listName"                      = $Name
            "userId"                        = $UserId
            "queryString"                   = $QueryString
            "listType"                      = $ListType
            "sharedAdministerAccessType"    = $SharedAdminAccessType
            "sharedEditAccessType"          = $SharedEditAccessType
            "sharedReadAccessType"          = $SharedViewAccessType
        } | ConvertTo-Json

        $contentType = "application/json"
        $headers = @{ 'X-API-KEY' = $ApiKey }
        $uri = "{0}/apiv1/lists/{1}"  -f  $instance, $endpoint

        if ($PSCmdlet.ShouldProcess($Name)) {
            $result = Invoke-WebRequest -Uri $uri -Headers $headers -Body $body -Method POST -ContentType $contentType

            return ($result.content | ConvertFrom-Json)
        }
    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}