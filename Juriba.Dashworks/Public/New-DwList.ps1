Function New-DwList {
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