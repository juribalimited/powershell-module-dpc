function Get-JuribaImportDevice {
    <#
        .SYNOPSIS
        Gets one or more imported devices.

        .DESCRIPTION
        Gets devices from the import API.
        Takes the ImportId as an input.
        Optionally takes a UniqueIdentifier as an input and will return a single device with that UniqueIdentifier.
        Optionally takes a Hostname as an input and will return all devices matching that hostname.
        Optionally takes a Filter as an input and will return all devices matching that filter. See swagger documentation for examples of using filters.
        If specified, only one of UniqueIdentifier, Hostname or Filter can be supplied. Omit all to return all devices for the import.

        .PARAMETER Instance

        Optional. Instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.platform.juriba.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER UniqueIdentifier

        UniqueIdentifier for the device. Cannot be used with Hostname or Filter.

        .PARAMETER ImportId

        ImportId for the device.

        .PARAMETER Hostname

        Hostname for the device. Cannot be used with UniqueIdentifier or Filter.

        .PARAMETER Filter

        Filter for device search. Cannot be used with Hostname or UniqueIdentifier.

        .PARAMETER Fields

        Array of fields to return. If specified, only these fields will be returned. This parameter is mutually exclusive with UniqueIdentifier and Filter.

        .PARAMETER InfoLevel

        Optional. Sets the level of information that this function returns. Accepts Basic or Full.
        Basic returns only the UniqueIdentifier, use when confirming a device exists.
        Full returns the full json object for the device.
        Default is Basic.

        .EXAMPLE
        PS> Get-JuribaImportDevice -Instance "https://myinstance.platform.juriba.app:8443" -APIKey "xxxxx" -ImportId 1 -InfoLevel "Full"

        .EXAMPLE
        PS> Get-JuribaImportDevice -Instance "https://myinstance.platform.juriba.app:8443" -APIKey "xxxxx" -ImportId 1 -UniqueIdentifier "123456789" -InfoLevel "Basic"

        .EXAMPLE
        PS> Get-JuribaImportDevice -Instance "https://myinstance.platform.juriba.app:8443" -APIKey "xxxxx" -ImportId 1 -Hostname "wabc123"

        .EXAMPLE
        PS> Get-JuribaImportDevice -Instance "https://myinstance.platform.juriba.app:8443" -APIKey "xxxxx" -ImportId 1 -Filter "eq(SerialNumber, 'zxy123456')"

    #>
    [alias("Get-DwImportDevice")]
    [OutputType([Object[]])]
    [CmdletBinding(DefaultParameterSetName="Default")]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory=$false, ParameterSetName="UniqueIdentifier")]
        [string]$UniqueIdentifier,
        [Parameter(Mandatory=$false, ParameterSetName="Hostname")]
        [string]$Hostname,
        [Parameter(Mandatory=$false, ParameterSetName="Filter")]
        [string]$Filter,
        [Parameter(Mandatory=$true)]
        [int]$ImportId,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Basic", "Full")]
        [string]$InfoLevel = "Basic",
        [Parameter(Mandatory=$false ,ParameterSetName="fields")]
        [string[]]$Fields
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $limit = 200 # page size

        #Check if version is 5.14 or newer
        $ver = Get-JuribaDPCVersion -Instance $Instance -MinimumVersion "5.14"
        if ($ver) {
            $uri = "{0}/apiv2/imports/{1}/devices" -f $Instance, $ImportId
        } else {
            $uri = "{0}/apiv2/imports/devices/{1}/items" -f $Instance, $ImportId
        }

        #build query string
        $query = @()

        # add limit to query if not getting by UniqueIdentifier
        if ($PSCmdlet.ParameterSetName -ne "UniqueIdentifier") {
            $query += "limit=$limit"
        }
        
        # add parameters to query based on parameter set
        switch ($PSCmdlet.ParameterSetName) {
            "UniqueIdentifier" {
                $uri += "/{0}" -f $UniqueIdentifier
            }
            "Hostname" {
                $query += "filter={0}" -f [System.Web.HttpUtility]::UrlEncode("eq(hostname,'{0}')" -f $Hostname)
            }
             "Filter" {
                $query += "filter={0}" -f [System.Web.HttpUtility]::UrlEncode($Filter)
            }
            "Fields" {
                $query += "fields={0}" -f [System.Web.HttpUtility]::UrlEncode($Fields -join ',')
                $InfoLevel = "Full"
            }
            Default { }
        }

        # build final uri
        if ($query.Count -gt 0) {
            $uri += $query | Join-String -Property $_ -Separator "&" -OutputPrefix "?"
        }
    
        $headers = @{
            'x-api-key' = $APIKey
            'cache-control' = 'no-cache'
        }
    
        $device = @()
        try {
            $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
            if ($result.Content -eq '[]') {return $device}
            $device = switch($InfoLevel) {
                "Basic" { ($result.Content | ConvertFrom-Json).UniqueIdentifier }
                "Full"  { $result.Content | ConvertFrom-Json }
            }
            # check if result is paged, if so get remaining pages and add to result set
            if ($result.Headers.ContainsKey("X-Pagination")) {
                $totalPages = ($result.Headers."X-Pagination" | ConvertFrom-Json).totalPages
                for ($page = 2; $page -le $totalPages; $page++) {
                    if ($uri -match '\?') {
                        $pagedUri = $uri + "&page={0}" -f $page
                    } else {
                        $pagedUri = $uri + "?page={0}" -f $page
                    }
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
                # 404 means the device was not found, don't treat this as an error
                # as we expect this function to be used to check if a device exists
                Write-Verbose "device not found"
            } else {
                Write-Error $_
            }
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
