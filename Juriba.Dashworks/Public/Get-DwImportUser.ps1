function Get-DwImportUser {
    <#
        .SYNOPSIS
        Gets one or more Dashworks users from the import API.

        .DESCRIPTION
        Gets a Dashworks users from the import API.
        Takes the ImportId as an input.
        Optionally takes a username as an input and will return a single user with that username.
        Optionally takes a Filter as an input and will return all users matching that filter. See swagger documentation for examples of using filters.
        If specified, only one of username or Filter can be supplied. Omit all to return all users for the import.

        .PARAMETER Instance

        Dashworks instance. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER Username

        Useraname for the user. Cannot be used with Filter.

        .PARAMETER ImportId

        ImportId for the user.

        .PARAMETER Filter

        Filter for user search. Cannot be used with Username.

        .PARAMETER InfoLevel

        Optional. Sets the level of information that this function returns. Accepts Basic or Full.
        Basic returns only the Username, use when confirming a user exists.
        Full returns the full json object for the user.
        Default is Basic.

        .EXAMPLE
        PS> Get-DwImportUser -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ImportId 1 -InfoLevel "Full"

        .EXAMPLE
        PS> Get-DwImportUser -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ImportId 1 -Username "123456789" -InfoLevel "Basic"

        .EXAMPLE
        PS> Get-DwImportUser -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ImportId 1 -Filter "eq(EmailAddress, 'zxy123456@x.com')"

         #>

    [CmdletBinding(DefaultParameterSetName="Default")]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [parameter(Mandatory=$false, ParameterSetName="Username")]
        [string]$Username,
        [parameter(Mandatory=$false, ParameterSetName="Filter")]
        [string]$Filter,
        [parameter(Mandatory=$true)]
        [int]$ImportId,
        [parameter(Mandatory=$false)]
        [ValidateSet("Basic", "Full")]
        [string]$InfoLevel = "Basic"
    )

    $limit = 50 # page size
    $uri = "{0}/apiv2/imports/users/{1}/items" -f $Instance, $ImportId

    switch ($PSCmdlet.ParameterSetName) {
        "Username" {
            $uri += "/{0}" -f $Username
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

    $user = ""
    try {
        $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
        $user = switch($InfoLevel) {
            "Basic" { ($result.Content | ConvertFrom-Json).Username }
            "Full"  { $result.Content | ConvertFrom-Json }
        }
        # check if result is paged, if so get remaining pages and add to result set
        if ($result.Headers.ContainsKey("X-Pagination")) {
            $totalPages = ($result.Headers."X-Pagination" | ConvertFrom-Json).totalPages
            for ($page = 2; $page -le $totalPages; $page++) {
                $pagedUri = $uri + "&page={0}" -f $page
                $pagedResult = Invoke-WebRequest -Uri $pagedUri -Method GET -Headers $headers -ContentType "application/json"
                $user += switch($InfoLevel) {
                    "Basic" { ($pagedResult.Content | ConvertFrom-Json).Username }
                    "Full"  { $pagedResult.Content | ConvertFrom-Json }
                }
            }
        }
        return $user
    }
    catch {
        if ($_.Exception.Response.StatusCode.Value__ -eq 404) {
            # 404 means the user was not found, don't treat this as an error
            # as we expect this function to be used to check if a user exists
            Write-Verbose "user not found"
        }
        else {
            Write-Error $_
        }
    }
}
