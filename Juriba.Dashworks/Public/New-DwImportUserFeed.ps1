#requires -Version 7
function New-DwImportUserFeed {
    <#
        .SYNOPSIS
        Creates a new user feed.

        .DESCRIPTION
        Creates a new user feed using the import API.
        Takes the feed name and an enabled boolean.

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER Name

        The name of the new user feed.

        .PARAMETER Enabled

        Should the new feed be enabled. Default = True.

        .EXAMPLE

        PS> New-DwImportUserFeed -Name "My New Import" -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

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
        $uri = "{0}/apiv2/imports/users" -f $Instance
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