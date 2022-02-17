#requires -Version 7
function Set-DwImportDeviceImport {
    <#
        .SYNOPSIS
        Updates a new device import. 

        .DESCRIPTION
        Updates a deivce import using the import API.
        Takes the new name and/or enabled status. 

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app

        .PARAMETER Port

        Dashworks API port number. Default = 8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER ImportId

        Id of import to be updated.
        
        .PARAMETER Name

        The name of the new device import.

        .PARAMETER Enabled

        Should the new import be enabled. 

        .EXAMPLE

        PS> Set-DwImportDeviceImport -ImportId 1 -Name "My New Import Name" -Enabled $false -Instance "myinstance.dashworks.app" -APIKey "xxxxx" 

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
        [parameter(Mandatory=$false)]
        [bool]$Enabled
    )

    if (-Not $Name -And -Not $Enabled) {
        throw "Either Name or Enabled must be specified."
    }
    
    $uri = "https://{0}:{1}/apiv2/imports/devices/{2}" -f $Instance, $Port, $ImportId
    $headers = @{'x-api-key' = $APIKey}

    $payload = @{}
    $payload.Add("name", $Name)
    $payload.Add("enabled", $Enabled)
    
    $JsonBody = $payload | ConvertTo-Json

    try {
        if ($PSCmdlet.ShouldProcess($ImportId) {
            $result = Invoke-RestMethod -Uri $uri -Method PATCH -Headers $headers -ContentType "application/json" -Body $jsonBody
        }
    }
    catch {
        Write-Error ("{0}. {1}" -f $_.Exception.Response.StatusCode.Value__, ($_ | ConvertFrom-Json).details)
        break
    }

    return $result
}