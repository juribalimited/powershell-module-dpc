Function Add-DwListTag {
    <#
    .SYNOPSIS

    Adds an existing tag to a list.

    .DESCRIPTION

    Adds an existing tag to a list using Dashworks API v1.

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Instance,
        [Parameter(Mandatory = $true)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox", "ApplicationUser", "ApplciationDevice")]
        [string]$ObjectType,
        [Parameter(Mandatory = $true)]
        [int]$ListId,
        [Parameter(Mandatory = $true)]
        [string]$Tag
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

    $body = @{
        tag = $Tag
    } | ConvertTo-Json

    $uri = "{0}/apiv1/lists/{1}/{2}/tag" -f $Instance, $endpoint, $ListId
    $headers = @{ 'x-api-key' = $APIKey }

    try {
        if ($PSCmdlet.ShouldProcess($Name)) {
            Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $body -ContentType 'application/json'
        }
    }
    catch {
            Write-Error $_
    }
}
