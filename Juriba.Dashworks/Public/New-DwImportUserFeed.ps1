#requires -Version 7
function New-DwImportUserFeed {
    <#
        .SYNOPSIS
        Creates a new user feed.

        .DESCRIPTION
        Creates a new user feed using the import API.
        Takes the feed name and an enabled boolean.

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER Name

        The name of the new user feed.

        .PARAMETER Enabled

        Should the new feed be enabled. Default = True.

        .EXAMPLE

        PS> New-DwImportUserFeed -Name "My New Import" -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [string]$Name,
        [parameter(Mandatory=$false)]
        [bool]$Enabled = $true
    )

    $uri = "{0}/apiv2/imports/users" -f $Instance
    $headers = @{'x-api-key' = $APIKey}

    $payload = @{}
    $payload.Add("name", $Name)
    $payload.Add("enabled", $Enabled)

    $JsonBody = $payload | ConvertTo-Json

    try {
        if ($PSCmdlet.ShouldProcess($Name)) {
            $result = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -ContentType "application/json" -Body $jsonBody
            return $result
        }
    }
    catch {
        Write-Error $_
    }
}