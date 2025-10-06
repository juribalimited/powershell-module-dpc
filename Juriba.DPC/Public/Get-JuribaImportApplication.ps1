function Get-JuribaImportApplication {
    [alias("Get-DwImportApplication")]
    <#
        .SYNOPSIS
        Gets applications from the import API.

        .DESCRIPTION
        Gets applications from the import API.
        Takes the ImportId and UniqueIdentifier as an input.
        Optionally takes a UniqueIdentifier as an input and will return a single application with that UniqueIdentifier.
        Optionally takes a Filter as an input and will return all applications matching that filter. See swagger documentation for examples of using filters.
        If specified, only one of UniqueIdentifier or Filter can be supplied. Omit all to return all devices for the import.

        .PARAMETER Instance

        Optional. Instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.platform.juriba.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER UniqueIdentifier

        UniqueIdentifier for the application.

        .PARAMETER ImportId

        ImportId for the application.

        .PARAMETER Filter

        Filter for application search.

        .PARAMETER InfoLevel

        Optional. Sets the level of information that this function returns. Accepts Basic or Full.
        Basic returns only the UniqueIdentifier, use when confirming an application exists.
        Full returns the full json object for the application.
        Default is Basic.

        .EXAMPLE
        PS> Get-JuribaImportApplication -Instance "https://myinstance.platform.juriba.app:8443" -APIKey "xxxxx" -ImportId 1 -InfoLevel "Full"

        .EXAMPLE
        PS> Get-JuribaImportApplication -Instance "https://myinstance.platform.juriba.app:8443" -APIKey "xxxxx" -ImportId 1 -UniqueIdentifier "123456789" -InfoLevel "Basic"

        .EXAMPLE
        PS> Get-JuribaImportApplication -Instance "https://myinstance.platform.juriba.app:8443" -APIKey "xxxxx" -ImportId 1 -Filter "eq(Manufacturer, 'zxy123456')"

    #>
    [OutputType([string])]
    [CmdletBinding(DefaultParameterSetName="Default")]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [parameter(Mandatory=$false, ParameterSetName="UniqueIdentifier")]
        [string]$UniqueIdentifier,
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
        $limit = 200 # page size

        #Check if version is 5.14 or newer
        $ver = Get-JuribaDPCVersion -Instance $Instance -MinimumVersion "5.14"
        if ($ver) {
            $uri = "{0}/apiv2/imports/{1}/applications" -f $Instance, $ImportId
        } else {
            $uri = "{0}/apiv2/imports/applications/{1}/items" -f $Instance, $ImportId
        }
           
        switch ($PSCmdlet.ParameterSetName) {
            "UniqueIdentifier" {
                $uri += "/{0}" -f $UniqueIdentifier
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
        $headers = @{'x-api-key' = $APIKey}
    
        $application = ""
        try {
            $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
            $application = switch($InfoLevel) {
                "Basic" { ($result.Content | ConvertFrom-Json).UniqueIdentifier }
                "Full"  { $result.Content | ConvertFrom-Json }
            }
            # check if result is paged, if so get remaining pages and add to result set
            if ($result.Headers.ContainsKey("X-Pagination")) {
                $totalPages = ($result.Headers."X-Pagination" | ConvertFrom-Json).totalPages
                for ($page = 2; $page -le $totalPages; $page++) {
                    $pagedUri = $uri + "&page={0}" -f $page
                    $pagedResult = Invoke-WebRequest -Uri $pagedUri -Method GET -Headers $headers -ContentType "application/json"
                    $application += switch($InfoLevel) {
                        "Basic" { ($pagedResult.Content | ConvertFrom-Json).UniqueIdentifier }
                        "Full"  { $pagedResult.Content | ConvertFrom-Json }
                    }
                }
            }
        }
        catch {
            if ($_.Exception.Response.StatusCode.Value__ -eq 404) {
                # 404 means the application was not found, don't treat this as an error
                # as we expect this function to be used to check if a application exists
                Write-Verbose "application not found"
            }
            else {
                Write-Error $_
            }
        }
        return $application

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
