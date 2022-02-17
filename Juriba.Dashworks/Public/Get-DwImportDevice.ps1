function Get-DwImportDevice {
    <#
        .SYNOPSIS
        Gets a Dashworks device from the import API.

        .DESCRIPTION
        Gets a Dashworks device from the import API.
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

        .PARAMETER InfoLevel

        Optional. Sets the level of information that this function returns. Accepts Basic or Full.
        Basic returns only the UniqueComputerIdentifier, use when confirming a device exists.
        Full returns the full json object for the device.
        Default is Basic.

        .EXAMPLE
        PS> Get-DwImportDevice -ImportId 1 -UniqueComputerIdentifier "w123abc" -Instance "myinstance.dashworks.app" -APIKey "xxxxx"
    #>

    [CmdletBinding()]
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
        [int]$ImportId,
        [parameter(Mandatory=$false)]
        [ValidateSet("Basic", "Full")]
        [string]$InfoLevel = "Basic"
    )

    $uri = "https://{0}:{1}/apiv2/imports/devices/{2}/items/{3}" -f $Instance, $Port, $ImportId, $UniqueComputerIdentifier
    $headers = @{'x-api-key' = $APIKey}

    $device = ''
    try {
        $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
        $device = switch($InfoLevel) {
            "Basic" { ($result.Content | ConvertFrom-Json).UniqueComputerIdentifier }
            "Full"  { $result.Content }
        }
    }
    catch {
        if ($_.Exception.Response.StatusCode.Value__ -eq 404) {
            Write-Information "device not found" -InformationAction Continue
        }
        else {
            Write-Error ("{0}. {1}" -f $_.Exception.Response.StatusCode.Value__, $_.Exception.Message)
        }
    }

    return $device
}