Function Remove-DwList {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox", "ApplicationUser", "ApplciationDevice")]
        [string]$ObjectType,
        [Parameter(Mandatory=$true)]
        [int]$ListId
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

    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = "{0}/apiv1/lists/{1}/{2}"  -f  $instance, $endpoint, $ListId

    Invoke-WebRequest -Uri $uri -Headers $headers -Method DELETE

}