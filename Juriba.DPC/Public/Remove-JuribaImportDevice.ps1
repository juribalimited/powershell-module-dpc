#Requires -Version 7
function Remove-JuribaImportDevice {
    [alias("Remove-DwImportDevice")]
    <#
        .SYNOPSIS
        Deletes a device in the import API.

        .DESCRIPTION
        Deletes a device in the import API.
        Takes the ImportId and UniqueIdentifier as an input.

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER UniqueIdentifier

        UniqueIdentifier for the device.

        .PARAMETER ImportId

        ImportId for the device.

        .EXAMPLE
        PS> Remove-JuribaImportDevice -ImportId 1 -UniqueIdentifier "w123abc" -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [string]$UniqueIdentifier,
        [parameter(Mandatory=$true)]
        [int]$ImportId
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
        } else {
            $uri = "{0}/apiv2/imports/devices/{1}/items/{2}" -f $Instance, $ImportId, $UniqueIdentifier
        }
        $headers = @{'x-api-key' = $APIKey}
    
        try {
            if ($PSCmdlet.ShouldProcess($UniqueIdentifier)) {
                $result = Invoke-WebRequest -Uri $uri -Method DELETE -Headers $headers
                return $result
            }
        }
        catch {
            Write-Error $_
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}