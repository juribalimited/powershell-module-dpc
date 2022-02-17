#Requires -Version 7
function Remove-DwImportDevice {
    <#
        .SYNOPSIS
        Deletes a device in the import API.

        .DESCRIPTION
        Deletes a device in the import API.
        Takes the ImportId and UniqueComputerIdentifier as an input.

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app

        .PARAMETER Port

        Dashworks API port number. Default = 8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER UniqueComputerIdentifier

        UniqueComputerIdentifier for the device.

        .PARAMETER ImportId

        ImportId for the device.

        .EXAMPLE
        PS> Remove-DwImportDevice -ImportId 1 -UniqueComputerIdentifier "w123abc" -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

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
        [string]$UniqueComputerIdentifier,
        [parameter(Mandatory=$true)]
        [int]$ImportId
    )

    $uri = "https://{0}:{1}/apiv2/imports/devices/{2}/items/{3}" -f $Instance, $Port, $ImportId, $UniqueComputerIdentifier
    $headers = @{'x-api-key' = $APIKey}

    try {
        if ($PSCmdlet.ShouldProcess($UniqueComputerIdentifier)) {
            $result = Invoke-WebRequest -Uri $uri -Method DELETE -Headers $headers
        }
    }
    catch {
        Write-Error ("{0}. {1}" -f $_.Exception.Response.StatusCode.Value__, ($_ | ConvertFrom-Json).details)
        break
    }

    return $result
}