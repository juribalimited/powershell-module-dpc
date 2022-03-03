#Requires -Version 7
function Set-DwImportDevice {
    <#
        .SYNOPSIS
        Updates a device in the import API.

        .DESCRIPTION
        Updates a device in the import API.
        Takes the ImportId, UniqueIdentifier and jsonBody as an input.

        .PARAMETER Instance

        Dashworks instance. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER UniqueIdentifier

        UniqueIdentifier for the device.

        .PARAMETER ImportId

        ImportId for the device.

        .PARAMETER JsonBody

        Json payload with updated device details.

        .EXAMPLE
        PS> Set-DwImportDevice -ImportId 1 -UniqueIdentifier "w123abc" -JsonBody $jsonBody -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [string]$UniqueIdentifier,
        [parameter(Mandatory=$true)]
        [int]$ImportId,
        [ValidateScript({
            Test-Json $_
        },
        ErrorMessage = "JsonBody is not valid json."
        )]
        [parameter(Mandatory=$true)]
        [string]$JsonBody
    )

    $uri = "{0}/apiv2/imports/devices/{1}/items/{2}" -f $Instance, $ImportId, $UniqueIdentifier
    $headers = @{'x-api-key' = $APIKey}

    try {
        if ($PSCmdlet.ShouldProcess($UniqueIdentifier)) {
            $result = Invoke-WebRequest -Uri $uri -Method PATCH -Headers $headers -ContentType "application/json" -Body $JsonBody
            return $result
        }
    }
    catch {
        Write-Error $_
    }

}