#requires -Version 7
function Set-DwImportDeviceFeed {
    <#
        .SYNOPSIS
        Updates a device feed.

        .DESCRIPTION
        Updates a deivce feed using the import API.
        Takes the new name and/or enabled status.

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Dw. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Dw.

        .PARAMETER ImportId

        Id of feed to be updated.

        .PARAMETER Name

        The name of the new device feed.

        .PARAMETER Enabled

        Should the new feed be enabled.

        .EXAMPLE

        PS> Set-DwImportDeviceFeed -ImportId 1 -Name "My New Import Name" -Enabled $false -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [int]$ImportId,
        [parameter(Mandatory=$false)]
        [string]$Name,
        [parameter(ParameterSetName = 'FeedEnabled', Mandatory = $false)]
        [bool]$Enabled
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        if (-Not $Name -And -Not $PSCmdlet.ParameterSetName -eq 'FeedEnabled') {
            throw "Either Name or Enabled must be specified."
        }
    
        $uri = "{0}/apiv2/imports/devices/{1}" -f $Instance, $ImportId
        $headers = @{'x-api-key' = $APIKey}
    
        $payload = @{}
        if ($name) { $payload.Add("name", $Name) }
        if ($PSCmdlet.ParameterSetName -eq 'FeedEnabled') { $payload.Add("enabled", $Enabled) }
    
        $jsonBody = $payload | ConvertTo-Json
    
        try {
            if ($PSCmdlet.ShouldProcess($ImportId)) {
                $result = Invoke-RestMethod -Uri $uri -Method PATCH -Headers $headers -ContentType "application/json" -Body $jsonBody
                return $result
            }
        }
        catch {
            if ($_.Exception.Response.StatusCode.Value__ -eq 409)
            {
                Write-Error ("{0}" -f "Update conflicted with another feed. Check if another feed exists with the same name.")
            }
            else {
                Write-Error $_
            }
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Dw before proceeding."
    }
}