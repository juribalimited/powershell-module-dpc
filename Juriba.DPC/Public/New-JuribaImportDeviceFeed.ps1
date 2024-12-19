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
        # Retrieve Juriba product version
        $versionUri = "{0}/apiv1/" -f $Instance
        $versionResult = Invoke-WebRequest -Uri $versionUri -Method GET
        # Regular expression to match the version pattern
        $regex = [regex]"\d+\.\d+\.\d+"

        # Extract the version
        $version = $regex.Match($versionResult).Value
        $versionParts = $version -split '\.'
        $major = [int]$versionParts[0]
        $minor = [int]$versionParts[1]

        # Check if the version is 5.13 or older
        if ($major -lt 5 -or ($major -eq 5 -and $minor -le 13)) {
            $uri = "{0}/apiv2/imports/devices" -f $Instance
        } else {
            $uri = "{0}/apiv2/imports" -f $Instance
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