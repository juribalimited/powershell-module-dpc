Function Get-DwList {
    <#
    .SYNOPSIS

    Returns existing Lists.

    .DESCRIPTION

    Returns existing lists using Dashworks API v1.

    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox", "ApplicationUser", "ApplicationDevice")]
        [string]$ObjectType
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
    
        #$contentType = "application/json"
        $headers = @{ 'X-API-KEY' = $ApiKey }
        $uri = "{0}/apiv1/lists/{1}"  -f  $instance, $endpoint
    
        $result = Invoke-WebRequest -Uri $uri -Headers $headers -Method GET # -ContentType $contentType
    
        return ($result.content | ConvertFrom-Json)

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}