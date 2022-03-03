function Get-DwImportDevice {
    <#
        .SYNOPSIS
        Gets one or more Dashworks devices from the import API.

        .DESCRIPTION
        Gets a Dashworks device from the import API.
        Takes the ImportId as an input.
        Optionally takes a UnqiueIdentifier as an input and will return a single device with that UniqueIdentifier.
        Optionally takes a Hostname as an input and will return all devices matching that hostname.
        Optionally takes a Filter as an input and will return all devices matching that filter. See swagger documentation for examples of using filters.
        If specified, only one of UniqueIdentifier, Hostname or Filter can be supplied. Omit all to return all devices for the import.

        .PARAMETER Instance

        Dashworks instance. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER UniqueIdentifier

        UniqueIdentifier for the device. Cannot be used with Hostname or Filter.

        .PARAMETER ImportId

        ImportId for the device.

        .PARAMETER Hostname

        Hostname for the deivce. Cannot be used with UniqueIdentifier or Filter.

        .PARAMETER Filter

        Filter for device search. Cannot be used with Hostname or UniqueIdentifier.

        .PARAMETER InfoLevel

        Optional. Sets the level of information that this function returns. Accepts Basic or Full.
        Basic returns only the UniqueIdentifier, use when confirming a device exists.
        Full returns the full json object for the device.
        Default is Basic.

        .EXAMPLE
        PS> Get-DwImportDevice -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ImportId 1 -InfoLevel "Full"

        .EXAMPLE
        PS> Get-DwImportDevice -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ImportId 1 -UniqueIdentifier "123456789" -InfoLevel "Basic"

        .EXAMPLE
        PS> Get-DwImportDevice -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ImportId 1 -Hostname "wabc123"

        .EXAMPLE
        PS> Get-DwImportDevice -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ImportId 1 -Filter "eq(SerialNumber, 'zxy123456')"

         #>

    [CmdletBinding(DefaultParameterSetName="UniuqeIdentifier")]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [parameter(Mandatory=$false, ParameterSetName="UniqueIdentifier")]
        [string]$UniqueIdentifier,
        [parameter(Mandatory=$false, ParameterSetName="Hostname")]
        [string]$Hostname,
        [parameter(Mandatory=$false, ParameterSetName="Filter")]
        [string]$Filter,
        [parameter(Mandatory=$true)]
        [int]$ImportId,
        [parameter(Mandatory=$false)]
        [ValidateSet("Basic", "Full")]
        [string]$InfoLevel = "Basic"
    )

    $limit = 1000 # page size
    $uri = "{0}/apiv2/imports/devices/{1}/items" -f $Instance, $ImportId

    switch ($PSCmdlet.ParameterSetName) {
        "UniqueIdentifier" {
            $uri += "/{0}" -f $UniqueIdentifier
        }
        "Hostname" {
            $uri += "?filter="
            $uri += [System.Web.HttpUtility]::UrlEncode("eq(hostname,'{0}')" -f $Hostname)
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
            # 404 means the device was not found, don't treat this as an error
            # as we expect this function to be used to check if a device exists
            Write-Verbose "device not found"
        }
        else {
            Write-Error $_
        }
    }
}