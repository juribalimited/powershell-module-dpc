#requires -Version 7
function Remove-JuribaImportDeviceFeedAllItem {
    [alias("Remove-DwImportDeviceFeedAllItem")]
    <#
        .SYNOPSIS
        Deletes all devices in a feed.

        .DESCRIPTION
        Deletes all devices in a feed.
        Takes Id of feed to be deleted.

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ImportId

        The Id of the device feed to be deleted.

        .EXAMPLE

        PS> Remove-JuribaImportDeviceFeedAllItem -ImportId 1 -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

        .EXAMPLE

        PS> Remove-JuribaImportDeviceFeedAllItem -Confirm:$false -ImportId 1 -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
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
            $uri = "{0}/apiv2/imports/{1}/devices" -f $Instance, $ImportId
        } else {
            $uri = "{0}/apiv2/imports/devices/{1}/items" -f $Instance, $ImportId
        }
        $headers = @{'x-api-key' = $APIKey}
    
        try {
            if ($PSCmdlet.ShouldProcess($ImportId)) {
                $result = Invoke-RestMethod -Uri $uri -Method DELETE -Headers $headers
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