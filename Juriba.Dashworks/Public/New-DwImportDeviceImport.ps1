#requires -Version 7
function New-DwImportDeviceImport {
    <#
        .SYNOPSIS
        Creates a new device import. 

        .DESCRIPTION
        Creates a new deivce import using the import API.
        Takes the import name and an enabled boolean. 

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app

        .PARAMETER Port

        Dashworks API port number. Default = 8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER Name

        The name of the new device import.

        .PARAMETER Enabled

        Should the new import be enabled. Default = True.

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
        [string]$Name,
        [parameter(Mandatory=$false)]
        [bool]$Enabled = $true
    )

    $uri = "https://{0}:{1}/apiv2/imports/devices" -f $Instance, $Port
    $headers = @{'x-api-key' = $APIKey}

    $payload = @{}
    $payload.Add("name", $Name)
    $payload.Add("enabled", $Enabled)
    
    $JsonBody = $payload | ConvertTo-Json

    try {
        if ($PSCmdlet.ShouldProcess($Name) {
            $result = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -ContentType "application/json" -Body $jsonBody
        }
    }
    catch {
        Write-Error ("{0}. {1}" -f $_.Exception.Response.StatusCode.Value__, ($_ | ConvertFrom-Json).details)
        break
    }

    return $result
}