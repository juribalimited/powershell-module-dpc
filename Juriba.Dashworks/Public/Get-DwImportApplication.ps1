function Get-DwImportApplication {
    <#
        .SYNOPSIS
        Gets a Dashworks application from the import API.

        .DESCRIPTION
        Gets a Dashworks application from the import API.
        Takes the ImportId and UniqueIdentifier as an input.
        Optionally takes a UnqiueIdentifier as an input and will return a single application with that UniqueIdentifier.
        Optionally takes a Filter as an input and will return all applications matching that filter. See swagger documentation for examples of using filters.
        If specified, only one of UniqueIdentifier or Filter can be supplied. Omit all to return all devices for the import.

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app

        .PARAMETER Port

        Dashworks API port number. Default = 8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER UniqueIdentifier

        UniqueIdentifier for the application.

        .PARAMETER ImportId

        ImportId for the application.

        .PARAMETER Filter

        Filter for application search. Cannot be used with Hostname or UniqueIdentifier.

        .PARAMETER InfoLevel

        Optional. Sets the level of information that this function returns. Accepts Basic or Full.
        Basic returns only the UniqueIdentifier, use when confirming an application exists.
        Full returns the full json object for the application.
        Default is Basic.

        .EXAMPLE
        PS> Get-DwImportApplication -Instance "myinstance.dashworks.app" -APIKey "xxxxx" -ImportId 1 -InfoLevel "Full"

        .EXAMPLE
        PS> Get-DwImportApplication -Instance "myinstance.dashworks.app" -APIKey "xxxxx" -ImportId 1 -UniqueIdentifier "123456789" -InfoLevel "Basic"

        .EXAMPLE
        PS> Get-DwImportApplication -Instance "myinstance.dashworks.app" -APIKey "xxxxx" -ImportId 1 -Filter "eq(Manufacturer, 'zxy123456')"

    #>

    [CmdletBinding(DefaultParameterSetName="UniuqeIdentifier")]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [int]$Port = 8443,
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

    $limit = 50 # page size
    $uri = "https://{0}:{1}/apiv2/imports/applications/{2}/items" -f $Instance, $Port, $ImportId

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
        return $application
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

}