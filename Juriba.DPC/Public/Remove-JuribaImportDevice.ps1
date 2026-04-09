#Requires -Version 7
function Remove-JuribaImportDevice {
    [alias("Remove-DwImportDevice")]
    <#
        .SYNOPSIS
        Deletes a device in the import API. Provide a list of JSON objects in request payload to use bulk functionality (Max 1000 objects per request).

        .DESCRIPTION
        Deletes a device in the import API. Provide a list of JSON objects in request payload to use bulk functionality (Max 1000 objects per request).
        Takes the ImportId and UniqueIdentifier as an input.

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER UniqueIdentifier

        Optional. UniqueIdentifier for the device. Optional only when submitting a bulk request (JsonBody to be provided instead).

        .PARAMETER ImportId

        ImportId for the device.

        .PARAMETER JsonBody

        Optional. Json payload for bulk deletion. Provide an array of URI strings for each object to be deleted (Max 1000 objects per request).

        .PARAMETER Async

        Optional. Send bulk requests asynchronously. Returns the job URI for polling with Wait-JuribaImportJob. Requires DPC 5.17 or later. Only applies to bulk requests.

        .EXAMPLE
        PS> Remove-JuribaImportDevice -ImportId 1 -UniqueIdentifier "w123abc" -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

        .EXAMPLE
        PS> Remove-JuribaImportDevice -ImportId 1 -JsonBody $jsonBody -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

        .EXAMPLE
        PS> Remove-JuribaImportDevice -ImportId 1 -JsonBody $jsonBody -Async -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$false)]
        [string]$UniqueIdentifier,
        [parameter(Mandatory=$true)]
        [int]$ImportId,
        [ValidateScript({
            Test-Json $_
        },
        ErrorMessage = "JsonBody is not valid json."
        )]
        [parameter(Mandatory=$false)]
        [string]$JsonBody,
        [parameter(Mandatory=$false)]
        [switch]$Async
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        #Check if version is 5.14 or newer
        $ver = Get-JuribaDPCVersion -Instance $instance -MinimumVersion "5.14"
        if ($ver) {
            $uri = "{0}/apiv2/imports/{1}/devices/{2}" -f $Instance, $ImportId, $UniqueIdentifier
            $bulkuri = "{0}/apiv2/imports/{1}/devices/`$bulk" -f $Instance, $ImportId
        } else {
            $uri = "{0}/apiv2/imports/devices/{1}/items/{2}" -f $Instance, $ImportId, $UniqueIdentifier
            $bulkuri = "{0}/apiv2/imports/devices/{1}/items/`$bulk" -f $Instance, $ImportId
        }
        if ($Async) {
            $asyncVer = Get-JuribaDPCVersion -Instance $Instance -MinimumVersion "5.17"
            if (-not $asyncVer) {
                throw "The -Async switch requires DPC version 5.17 or later."
            }
            $bulkuri += "?async"
        }

        $headers = @{'x-api-key' = $APIKey}

        try {
            if ($UniqueIdentifier) {
                if ($PSCmdlet.ShouldProcess($UniqueIdentifier)) {
                    $result = Invoke-WebRequest -Uri $uri -Method DELETE -Headers $headers
                    return $result
                }
            }
            elseif ($JsonBody) {
                if ($PSCmdlet.ShouldProcess($ImportId)) {
                    if ($Async) {
                        $response = Invoke-WebRequest -Uri $bulkuri -Method DELETE -Headers $headers -ContentType "application/json" -Body ([System.Text.Encoding]::UTF8.GetBytes($JsonBody))
                        if ($response.Headers.Location.Length -gt 0) {
                            return $response.Headers.Location
                        } else {
                            throw "No job location returned in async response headers."
                        }
                    } else {
                        $result = Invoke-RestMethod -Uri $bulkuri -Method DELETE -Headers $headers -ContentType "application/json" -Body ([System.Text.Encoding]::UTF8.GetBytes($JsonBody))
                        return $result
                    }
                }
            }
        }
        catch {
            Write-Error $_
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}