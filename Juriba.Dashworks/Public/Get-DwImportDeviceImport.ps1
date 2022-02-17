#requires -Version 7
function Get-DwImportDeviceImport {
    <#
        .SYNOPSIS
        Gets device imports. 

        .DESCRIPTION
        Gets one or more device imports.
        Use ImportId to get a specific import or omit for all import. 

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app

        .PARAMETER Port

        Dashworks API port number. Default = 8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER ImportId

        Optional. The id for the device import. Omit to get all device imports. 

        .EXAMPLE

        PS> Get-DwImportDeviceImport -ImportId 1 -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [int]$Port = 8443,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [parameter(Mandatory=$false)]
        [int]$ImportId
    )

    $uri = "https://{0}:{1}/apiv2/imports/devices{2}" -f $Instance, $Port, (if ($ImportId) { "/$importId"})
    $headers = @{'x-api-key' = $APIKey}
    
    try {
        $result = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json" -Body $jsonBody
    }
    catch {
        Write-Error ("{0}. {1}" -f $_.Exception.Response.StatusCode.Value__, ($_ | ConvertFrom-Json).details)
        break
    }

    return $result
}