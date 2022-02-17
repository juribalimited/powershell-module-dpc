#requires -Version 7
function Remove-DwImportDeviceImport {
    <#
        .SYNOPSIS
        Deletes a device import. 

        .DESCRIPTION
        Deletes a device import.
        Takes Id of import to be deleted. 

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app

        .PARAMETER Port

        Dashworks API port number. Default = 8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER ImportId

        The Id of the device import to be deleted. 

        .EXAMPLE

        PS> Remove-DwImportDeviceImport -ImportId 1 -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

        .EXAMPLE 

        PS> Remove-DwImportDeviceImport -Confirm:$false -ImportId 1 -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

    #>
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [int]$Port = 8443,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [int]$ImportId
    )

    $uri = "https://{0}:{1}/apiv2/imports/{2}" -f $Instance, $Port, $ImportId
    $headers = @{'x-api-key' = $APIKey}
    
    try {
        if ($PSCmdlet.ShouldProcess($ImportId) {
            $result = Invoke-RestMethod -Uri $uri -Method DELETE -Headers $headers 
        }
    }
    catch {
        Write-Error ("{0}. {1}" -f $_.Exception.Response.StatusCode.Value__, ($_ | ConvertFrom-Json).details)
        break
    }

    return $result
}