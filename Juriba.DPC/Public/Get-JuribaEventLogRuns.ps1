function Get-JuribaEventLogRuns {
    <#
        .SYNOPSIS
        Retrieves recent runs for a specified service from the Juriba API.

        .DESCRIPTION
        Queries the Juriba API to retrieve details about a specific run for a particular service by its name. 
        It supports pagination and allows filtering and ordering of results.

        .PARAMETER Instance

        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ServiceName

        The name of the service to search for in the event log services.

        .PARAMETER Page
        
        (Optional) Jump to a specific page.

        .PARAMETER Filter

        (Optional) A filter string to narrow down the results. Defaults to an empty string.

        .PARAMETER Order

        (Optional) Specifies the order of the results. Defaults to an empty string.

        .PARAMETER Latest

        (Optional) Forces page to be 1, returns only the latest run for the specified service

        .EXAMPLE

        PS> Get-JuribaEventLogRuns -Instance $Instance -APIKey $APIKey -ServiceID $ETLID.id -Latest -ErrorAction Stop
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        
        [Parameter(Mandatory = $false)]
        [string]$APIKey,

        [Parameter(Mandatory = $true)]
        [int]$ServiceID,

        [Parameter(Mandatory = $false)]
        [string]$Filter = "",

        [Parameter(Mandatory = $false)]
        [int]$Page = 1,

        [Parameter(Mandatory = $false)]
        [string]$Order = "-datestart",

        [Parameter(Mandatory = $false)]
        [switch]$Latest
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    # Default filter: if no filter is provided then filter by ServiceID.
    if (-not $Filter -or -not $Filter.Trim()) {
        $Filter = "eq(serviceId,%27$ServiceID%27)"
    }

    $baseUri = "$Instance/apiv2/event-logs/runs"
    $headers = @{ "X-API-KEY" = $APIKey }

    # When $Latest is specified, force Page=1.
    if ($Latest) { $Page = 1 }

    # Build query parameters.
    $queryParams = @{}

    if ($Page) { $queryParams["page"] = $Page }
    if ($Order -and $Order.Trim()) { $queryParams["order"] = $Order }
    if ($Filter -and $Filter.Trim()) { $queryParams["filter"] = $Filter }

    $qsParts = @()

    foreach ($key in $queryParams.Keys) {
        $qsParts += "$key=$($queryParams[$key])"
    }

    $queryString = $qsParts -join "&"
    if ($queryString) { $uri = "$($baseUri)?$queryString" } else { $uri = $baseUri }

    Write-Verbose "Calling: $uri"
    try{
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET -ErrorAction Stop
    } catch {
        Write-Error "Error calling API endpoint: $_"
        return $null
    }
    
    if ($Latest) {
        if (($response | Measure-Object).Count -gt 0) {
            return $response[0]
        } else {
            Write-Warning "No runs found."
            return $null
        }
    } else {
        return $response
    }
}