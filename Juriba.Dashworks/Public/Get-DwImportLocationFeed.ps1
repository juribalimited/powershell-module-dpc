#requires -Version 7
function Get-DwImportLocationFeed {
    <#
        .SYNOPSIS
        Gets location imports.
        .DESCRIPTION
        Gets one or more location feeds.
        Use ImportId to get a specific feed or omit for all feeds.
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ImportId
        Optional. The id for the location feed. Omit to get all location feeds.
        .PARAMETER Name
        Optional. Name of location feed to find. Can only be used when ImportId is not specified.
        .EXAMPLE
        PS> Get-DwImportLocationFeed -ImportId 1 -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"
        .EXAMPLE
        PS> Get-DwImportLocationFeed -Name "My Location Feed" -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$false, ParameterSetName="ImportId")]
        [int]$ImportId,
        [parameter(Mandatory=$false, ParameterSetName="Name")]
        [string]$Name
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $uri = "{0}/apiv2/imports/locations" -f $Instance
        switch ($PSCmdlet.ParameterSetName) {
            "ImportId" {
                $uri += "/{0}" -f $ImportId
            }
            "Name" {
                $uri += "?filter="
                $uri += [System.Web.HttpUtility]::UrlEncode("eq(name,'{0}')" -f $Name)
            }
        }
    
        $headers = @{'x-api-key' = $APIKey}
    
        try {
            $result = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
            return $result
        }
        catch {
            Write-Error $_
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}