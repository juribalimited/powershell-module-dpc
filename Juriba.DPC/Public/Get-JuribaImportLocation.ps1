function Get-JuribaImportLocation {
    [alias("Get-DwImportLocation")]
    <#
        .SYNOPSIS
        Gets one or more Dashworks devices from the import API.

        .DESCRIPTION
        Gets a Dashworks Location from the import API.
        Takes the ImportId as an input.
        Optionally takes a UnqiueIdentifier as an input and will return a single location with that UniqueIdentifier.
        Optionally takes a Hostname as an input and will return all location matching that hostname.
        Optionally takes a Filter as an input and will return all location matching that filter. See swagger documentation for examples of using filters.
        If specified, only one of UniqueIdentifier, Hostname or Filter can be supplied. Omit all to return all locations for the import.

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER UniqueIdentifier

        UniqueIdentifier for the location. Cannot be used with LocationName or Filter.

        .PARAMETER ImportId

        ImportId for the location.

        .PARAMETER LocationName

        Name for the location.

        .PARAMETER Filter

        Filter for location search.

        .PARAMETER InfoLevel

        Optional. Sets the level of information that this function returns. Accepts Basic or Full.
        Basic returns only the UniqueIdentifier, use when confirming a location exists.
        Full returns the full json object for the location.
        Default is Basic.

        .EXAMPLE
        PS> Get-JuribaImportLocation -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ImportId 1 -Filter "eq(Region, 'EU')"

         #>

    [CmdletBinding(DefaultParameterSetName="UniqueIdentifier")]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$false, ParameterSetName="UniqueIdentifier")]
        [string]$UniqueIdentifier,
        [parameter(Mandatory=$false, ParameterSetName="LocationName")]
        [string]$LocationName,
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
        $limit = 1000 # page size
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
            $uri = "{0}/apiv2/imports/locations/{1}/items" -f $Instance, $ImportId
        } else {
            $uri = "{0}/apiv2/imports/{1}/locations" -f $Instance, $ImportId
        }
    
        switch ($PSCmdlet.ParameterSetName) {
            "UniqueIdentifier" {
                $uri += "/{0}" -f $UniqueIdentifier
            }
            "LocationName" {
                $uri += "?filter="
                $uri += [uri]::EscapeDataString("eq(name,'{0}')" -f $LocationName)
                $uri += "&limit={0}" -f $limit
            }
            "Filter" {
                $uri += "?filter="
                $uri += [uri]::EscapeDataString("{0}" -f $Filter)
                $uri += "&limit={0}" -f $limit
            }
            Default {
                $uri += "?limit={0}" -f $limit
            }
        }
    
        $headers = @{'x-api-key' = $APIKey}
    
        $device = ""
        try {
            $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
            $device = switch($InfoLevel) {
                "Basic" { ($result.Content | ConvertFrom-Json).UniqueIdentifier }
                "Full"  { $result.Content | ConvertFrom-Json }
            }
            # check if result is paged, if so get remaining pages and add to result set
            if ($result.Headers.ContainsKey("X-Pagination")) {
                $totalPages = ($result.Headers."X-Pagination" | ConvertFrom-Json).totalPages
                for ($page = 2; $page -le $totalPages; $page++) {
                    $pagedUri = $uri + "&page={0}" -f $page
                    $pagedResult = Invoke-WebRequest -Uri $pagedUri -Method GET -Headers $headers -ContentType "application/json"
                    $device += switch($InfoLevel) {
                        "Basic" { ($pagedResult.Content | ConvertFrom-Json).UniqueIdentifier }
                        "Full"  { $pagedResult.Content | ConvertFrom-Json }
                    }
                }
            }
            return $device
        }
        catch {
            if ($_.Exception.Response.StatusCode.Value__ -eq 404) {
                # 404 means the location was not found, don't treat this as an error
                # as we expect this function to be used to check if a device exists
                Write-Verbose "Location not found"
            }
            else {
                Write-Error $_
            }
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}