#requires -Version 7
function Set-DwImportDeviceFeed {
    <#
        .SYNOPSIS
        Updates a device feed.

        .DESCRIPTION
        Updates a deivce feed using the import API.
        Takes the new name and/or enabled status.

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app

        .PARAMETER Port

        Dashworks API port number. Default = 8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER ImportId

        Id of feed to be updated.

        .PARAMETER Name

        The name of the new device feed.

        .PARAMETER Enabled

        Should the new feed be enabled.

        .EXAMPLE

        PS> Set-DwImportDeviceFeed -ImportId 1 -Name "My New Import Name" -Enabled $false -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [int]$Port = 8443,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [int]$ImportId,
        [parameter(Mandatory=$false)]
        [string]$Name,
        [parameter(ParameterSetName = 'FeedEnabled', Mandatory = $false)]
        [bool]$Enabled
    )

    if (-Not $Name -And -Not $PSCmdlet.ParameterSetName -eq 'FeedEnabled') {
        throw "Either Name or Enabled must be specified."
    }

    $uri = "https://{0}:{1}/apiv2/imports/devices/{2}" -f $Instance, $Port, $ImportId
    $headers = @{'x-api-key' = $APIKey}

    $payload = @{}
    if ($name) { $payload.Add("name", $Name) }
    if ($PSCmdlet.ParameterSetName -eq 'FeedEnabled') { $payload.Add("enabled", $Enabled) }

    $jsonBody = $payload | ConvertTo-Json

    try {
        if ($PSCmdlet.ShouldProcess($ImportId)) {
            $result = Invoke-RestMethod -Uri $uri -Method PATCH -Headers $headers -ContentType "application/json" -Body $jsonBody
            return $result
        }
    }
    catch {
        if ($_.Exception.Response.StatusCode.Value__ -eq 409)
        {
            Write-Error ("{0}" -f "Update conflicted with another feed. Check if another feed exists with the same name.")
        }
        else {
            Write-Error $_
        }
    }
}