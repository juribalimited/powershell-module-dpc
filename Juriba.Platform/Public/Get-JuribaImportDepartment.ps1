function Get-JuribaImportDepartment {
    [alias("Get-DwImportDepartment")]
    <#
        .SYNOPSIS
        Gets one or more Dashworks departments from the import API.

        .DESCRIPTION
        Gets a Dashworks departments from the import API.
        Takes the ImportId as an input.
        Optionally takes a name as an input and will return a single department with that name.
        Optionally takes a Filter as an input and will return all departments matching that filter. See swagger documentation for examples of using filters.
        If specified, only one of name or Filter can be supplied. Omit all to return all departments for the import.

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER Name

        Name for the department. Cannot be used with Filter.

        .PARAMETER ImportId

        ImportId for the department.

        .PARAMETER Filter

        Filter for department search. Cannot be used with Name.

        .PARAMETER InfoLevel

        Optional. Sets the level of information that this function returns. Accepts Basic or Full.
        Basic returns only the Name, use when confirming a department exists.
        Full returns the full json object for the department.
        Default is Basic.

        .EXAMPLE
        PS> Get-JuribaImportDepartment -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ImportId 1 -InfoLevel "Full"

        .EXAMPLE
        PS> Get-JuribaImportDepartment -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ImportId 1 -Name "Sales" -InfoLevel "Basic"

        .EXAMPLE
        PS> Get-JuribaImportDepartment -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ImportId 1 -Filter "eq(Name, 'zxy123456@x.com')"

         #>

    [CmdletBinding(DefaultParameterSetName="Default")]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
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
        $uri = "{0}/apiv2/imports/departments/{1}/items" -f $Instance, $ImportId
    
        switch ($PSCmdlet.ParameterSetName) {
            "Name" {
                $uri += "?filter="
                $uri += [System.Web.HttpUtility]::UrlEncode("eq(Name,'{0}')" -f $Name)
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
    
        $department = ""
        try {
            $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
            $department = switch($InfoLevel) {
                "Basic" { ($result.Content | ConvertFrom-Json).Name }
                "Full"  { $result.Content | ConvertFrom-Json }
            }
            # check if result is paged, if so get remaining pages and add to result set
            if ($result.Headers.ContainsKey("X-Pagination")) {
                $totalPages = ($result.Headers."X-Pagination" | ConvertFrom-Json).totalPages
                for ($page = 2; $page -le $totalPages; $page++) {
                    $pagedUri = $uri + "&page={0}" -f $page
                    $pagedResult = Invoke-WebRequest -Uri $pagedUri -Method GET -Headers $headers -ContentType "application/json"
                    $department += switch($InfoLevel) {
                        "Basic" { ($pagedResult.Content | ConvertFrom-Json).Name }
                        "Full"  { $pagedResult.Content | ConvertFrom-Json }
                    }
                }
            }
            return $department
        }
        catch {
            if ($_.Exception.Response.StatusCode.Value__ -eq 404) {
                # 404 means the department was not found, don't treat this as an error
                # as we expect this function to be used to check if a department exists
                Write-Verbose "department not found"
            }
            else {
                Write-Error $_
            }
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}