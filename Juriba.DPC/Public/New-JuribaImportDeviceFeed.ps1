#requires -Version 7
function New-JuribaImportDeviceFeed {
    [alias("New-DwImportDeviceFeed")]
    <#
        .SYNOPSIS
        Creates a new device feed.

        .DESCRIPTION
        Creates a new deivce feed using the import API.
        Takes the feed name and an enabled boolean.

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER Name

        The name of the new device feed.

        .PARAMETER Enabled

        Should the new feed be enabled. Default = True.

        .EXAMPLE

        PS> New-JuribaImportDeviceFeed -Name "My New Import" -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [string]$Name,
        [parameter(Mandatory=$false)]
        [bool]$Enabled = $true
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        #Check if version is 5.14 or newer
        $ver = Get-JuribaDPCVersion -Instance $instance -MinimumVersion "5.14"
        if ($ver) {
            $uri = "{0}/apiv2/imports" -f $Instance
        } else {
            $uri = "{0}/apiv2/imports/devices" -f $Instance
        }
        $headers = @{'x-api-key' = $APIKey}
    
        $payload = @{}
        $payload.Add("name", $Name)
        $payload.Add("enabled", $Enabled)
    
        $JsonBody = $payload | ConvertTo-Json
    
        try {
            if ($PSCmdlet.ShouldProcess($Name)) {
                $result = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -ContentType "application/json" -Body $jsonBody
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