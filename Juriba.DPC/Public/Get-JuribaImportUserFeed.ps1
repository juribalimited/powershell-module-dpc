#requires -Version 7
function Get-JuribaImportUserFeed {
    [alias("Get-DwImportUserFeed")]
    <#
        .SYNOPSIS
        Gets user imports.
        .DESCRIPTION
        Gets one or more user feeds.
        Use ImportId to get a specific feed or omit for all feeds.
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ImportId
        Optional. The id for the user feed. Omit to get all user feeds.
        .PARAMETER Name
        Optional. Name of user feed to find. Can only be used when ImportId is not specified.
        .EXAMPLE
        PS> Get-JuribaImportUserFeed -ImportId 1 -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"
        .EXAMPLE
        PS> Get-JuribaImportUserFeed -Name "My User Feed" -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"
    #>
    [CmdletBinding(DefaultParameterSetName="Name")]
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
        # Retrieve Juriba product version
        $versionUri = "{0}/apiv1/" -f $Instance
        $versionResult = Invoke-WebRequest -Uri $versionUri -Method GET -Headers $headers -ContentType "application/json"
        # Regular expression to match the version pattern
        $regex = [regex]"\d+\.\d+\.\d+"

        # Extract the version
        $version = $regex.Match($versionResult).Value
        $versionParts = $version -split '\.'
        $major = [int]$versionParts[0]
        $minor = [int]$versionParts[1]

        # Check if the version is 5.13 or older
        if ($major -lt 5 -or ($major -eq 5 -and $minor -le 13)) {
            $uri = "{0}/apiv2/imports/users" -f $Instance
        } else {
            $uri = "{0}/apiv2/imports" -f $Instance
        }
        
        if ($ImportId) {$uri += "/{0}" -f $ImportId}
        if ($Name) {
            $uri += "?filter="
            $uri += [System.Web.HttpUtility]::UrlEncode("eq(name,'{0}')" -f $Name)
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