function Get-JuribaImportGroup {
    <#
        .SYNOPSIS
        Gets groups from the import API.

        .DESCRIPTION
        Gets groups from the import API.
        Takes the User import ImportId as an input.
        Optionally takes a UniqueIdentifier as an input and will return a single group with that UniqueIdentifier.
        Optionally takes a Name as an input and will return all groups matching the provided group name.
        Optionally takes a Filter as an input and will return all groups matching that filter. See swagger documentation for examples of using filters.
        If specified, only one of UniqueIdentifier, Name or Filter can be supplied. Omit all to return all objects for the import.

        .PARAMETER Instance

        Optional. Instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.platform.juriba.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER UniqueIdentifier

        UniqueIdentifier for the group. Cannot be used with Name or Filter.

        .PARAMETER ImportId

        ImportId from User import feed.

        .PARAMETER Name

        Name of the group. Cannot be used with UniqueIdentifier or Filter.

        .PARAMETER Filter

        Filter for group search. Cannot be used with Name or UniqueIdentifier.

        .PARAMETER InfoLevel

        Optional. Sets the level of information that this function returns. Accepts Basic or Full.
        Basic returns only the UniqueIdentifier, use when confirming a group exists.
        Full returns the full json object for the group.
        Default is Basic.

        .EXAMPLE
        PS> Get-JuribaImportGroup -Instance "https://myinstance.platform.juriba.app:8443" -APIKey "xxxxx" -ImportId 1 -InfoLevel "Full"

        .EXAMPLE
        PS> Get-JuribaImportGroup -Instance "https://myinstance.platform.juriba.app:8443" -APIKey "xxxxx" -ImportId 1 -UniqueIdentifier "123456789" -InfoLevel "Basic"

        .EXAMPLE
        PS> Get-JuribaImportGroup -Instance "https://myinstance.platform.juriba.app:8443" -APIKey "xxxxx" -ImportId 1 -Name "wabc123"

        .EXAMPLE
        PS> Get-JuribaImportGroup -Instance "https://myinstance.platform.juriba.app:8443" -APIKey "xxxxx" -ImportId 1 -Filter "eq(domain, 'zxy123456')"

         #>

    [CmdletBinding(DefaultParameterSetName="Default")]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$false, ParameterSetName="UniqueIdentifier")]
        [string]$UniqueIdentifier,
        [parameter(Mandatory=$false, ParameterSetName="Name")]
        [string]$Name,
        [parameter(Mandatory=$false, ParameterSetName="Filter")]
        [string]$Filter,
        [parameter(Mandatory=$true)]
        [int]$ImportId,
        [parameter(Mandatory=$false)]
        [ValidateSet("Basic", "Full")]
        [string]$InfoLevel = "Basic"
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $limit = 50 # page size
        #Check if version is 5.14 or newer
        $ver = Get-JuribaDPCVersion -Instance $Instance -MinimumVersion "5.14"
        if ($ver) {
            $uri = "{0}/apiv2/imports/{1}/groups" -f $Instance, $ImportId
        } else {
            $uri = "{0}/apiv2/imports/groups/{1}/items" -f $Instance, $ImportId
        }
    
        switch ($PSCmdlet.ParameterSetName) {
            "UniqueIdentifier" {
                $uri += "/{0}" -f $UniqueIdentifier
            }
            "Name" {
                $uri += "?filter="
                $uri += [System.Web.HttpUtility]::UrlEncode("eq(name,'{0}')" -f $Name)
                $uri += "&limit={0}" -f $limit
            }
            "Filter" {
                $uri += "?filter="
                $uri += [System.Web.HttpUtility]::UrlEncode("{0}" -f $Filter)
                $uri += "&limit={0}" -f $limit
            }
            Default {
                $uri += "?limit={0}" -f $limit
            }
        }
    
        $headers = @{
            'x-api-key' = $APIKey
            'cache-control' = 'no-cache'
        }
        
        $group = ""
        try {
            $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
            $group = switch($InfoLevel) {
                "Basic" { ($result.Content | ConvertFrom-Json).UniqueIdentifier }
                "Full"  { $result.Content | ConvertFrom-Json }
            }
            # check if result is paged, if so get remaining pages and add to result set
            if ($result.Headers.ContainsKey("X-Pagination")) {
                $totalPages = ($result.Headers."X-Pagination" | ConvertFrom-Json).totalPages
                for ($page = 2; $page -le $totalPages; $page++) {
                    $pagedUri = $uri + "&page={0}" -f $page
                    $pagedResult = Invoke-WebRequest -Uri $pagedUri -Method GET -Headers $headers -ContentType "application/json"
                    $group += switch($InfoLevel) {
                        "Basic" { ($pagedResult.Content | ConvertFrom-Json).UniqueIdentifier }
                        "Full"  { $pagedResult.Content | ConvertFrom-Json }
                    }
                }
            }
            return $group
        }
        catch {
            Write-Error $_.Exception.Response
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
