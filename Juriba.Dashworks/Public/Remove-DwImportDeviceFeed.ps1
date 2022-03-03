#requires -Version 7
function Remove-DwImportDeviceFeed {
    <#
        .SYNOPSIS
        Deletes a device feed.

        .DESCRIPTION
        Deletes a device feed.
        Takes Id of feed to be deleted.

        .PARAMETER Instance

        Dashworks instance. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER ImportId

        The Id of the device feed to be deleted.

        .EXAMPLE

        PS> Remove-DwImportDeviceFeed -ImportId 1 -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

        .EXAMPLE

        PS> Remove-DwImportDeviceFeed -Confirm:$false -ImportId 1 -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [int]$ImportId
    )

    $uri = "{0}/apiv2/imports/devices/{1}" -f $Instance, $ImportId
    $headers = @{'x-api-key' = $APIKey}

    try {
        if ($PSCmdlet.ShouldProcess($ImportId)) {
            $result = Invoke-RestMethod -Uri $uri -Method DELETE -Headers $headers
            return $result
        }
    }
    catch {
        Write-Error $_
    }
}