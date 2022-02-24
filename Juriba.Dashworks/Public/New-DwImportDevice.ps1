#Requires -Version 7
function New-DwImportDevice {
    <#
        .SYNOPSIS
        Creates a new Dashworks device using the import API.

        .DESCRIPTION
        Creates a new Dashworks device using the import API.
        Takes the ImportId and JsonBody as an input.

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app

        .PARAMETER Port

        Dashworks API port number. Default = 8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER ImportId

        ImportId for the device.

        .PARAMETER JsonBody

        Json payload with updated device details.

        .EXAMPLE
        PS> New-DwImportDevice -ImportId 1 -JsonBody $jsonBody -Instance "myinstance.dashworks.app" -APIKey "xxxxx"
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
        [ValidateScript({
            ((Test-Json $_) -and (($_ | ConvertFrom-Json).uniqueComputerIdentifier))
        },
        ErrorMessage = "JsonBody is not valid json or does not contain a uniqueComputerIdentifier"
        )]
        [parameter(Mandatory=$true)]
        [string]$JsonBody
    )

    $uri = "https://{0}:{1}/apiv2/imports/devices/{2}/items" -f $Instance, $Port, $ImportId
    $headers = @{'x-api-key' = $APIKey}

    try {
        if ($PSCmdlet.ShouldProcess(($JsonBody | ConvertFrom-Json).uniqueComputerIdentifier)) {
            $result = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -ContentType "application/json" -Body $jsonBody
            return $result
        }
    }
    catch {
        Write-Error $_
    }

}