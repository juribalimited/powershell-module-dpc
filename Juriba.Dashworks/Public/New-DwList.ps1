Function New-DwList {
    <#
        .SYNOPSIS
        Creates a new list.

        .DESCRIPTION
        Uses ApiV1 to create a new list.

        .PARAMETER Instance

        Dashworks instance. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER Name

        Name for the new list.

        .PARAMETER UserId

        UserId for the user who will own this list. See Get-DwSessionUser.

        .PARAMETER ListType

        The type of list to create. Accepts one of: "Dynamic", "Static" or "Dynamic Pivot"

        .PARAMETER QueryString

        The query string for the new list. The easiest way to generate this is to create the list you want in the UI then, using broswer
        dev tools, capture the POST request when saving the list. Use the QueryString property from the captured request payload.
        Note that $ characters may need escaping if PowerShell interprets them as variables.

        .PARAMETER ObjectType

        Base object type for the new list. Accepts one of: "Device", "User", "Application", "Mailbox", "ApplicationUser", "ApplciationDevice"

        .EXAMPLE

        PS> New-DwList
            -Instance "https://myinstance.dashworks.app:8443"
            -APIKey "xxxxx"
            -Name "My New List"
            -UserId ((Get-DwSessionUser).userId)
            -ListType Dynamic
            -QueryString "`$filter=&`$select=hostname,chassisCategory,oSCategory,ownerDisplayName,bootupDate&`$pinleft=&`$pinright=&`$archiveditems=false"
            -ObjectType "Device"

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
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
        [string]$ObjectType
    )

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
        "sharedAdministerAccessType"    = "Owner"
        "sharedEditAccessType"          = "Owner"
        "sharedReadAccessType"          = "Everyone"
    } | ConvertTo-Json

    $contentType = "application/json"
    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = "{0}/apiv1/lists/{1}"  -f  $instance, $endpoint

    if ($PSCmdlet.ShouldProcess($Name)) {
        $result = Invoke-WebRequest -Uri $uri -Headers $headers -Body $body -Method POST -ContentType $contentType

        return ($result.content | ConvertFrom-Json)
    }


}