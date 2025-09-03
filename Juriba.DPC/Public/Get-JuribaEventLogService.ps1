#requires -Version 7
function Get-JuribaEventLogService {
    [Alias("Get-JuribaEventLogServices")]
    <#
        .SYNOPSIS
        Retrieves service information from the Juriba API.

        .DESCRIPTION
        Queries the Juriba API to retrieve details about a specific service by its name. 
        It supports pagination and allows filtering and ordering of results.

        .PARAMETER Instance

        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ServiceName

        The name of the service to search for in the event log services.

        .PARAMETER Filter

        (Optional) A filter string to narrow down the results. Defaults to an empty string.

        .PARAMETER Order

        (Optional) Specifies the order of the results. Defaults to an empty string.

        .EXAMPLE

        PS> Get-JuribaEventLogServices -Instance $Instance -APIKey $APIKey -ServiceName "ETL" -ErrorAction Stop
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,

        [Parameter(Mandatory = $false)]
        [string]$APIKey,

        [Parameter(Mandatory = $true)]
        [string]$ServiceName,

        [Parameter(Mandatory = $false)]
        [string]$Filter = "",

        [Parameter(Mandatory = $false)]
        [string]$Order = ""
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    # Construct URI using Instance and fixed path.
    $baseUri = "$Instance/apiv2/event-logs/services"
    $headers = @{ "X-API-KEY" = $APIKey }
    
    $page = 1
    $foundService = $null

    do {
        # Build query parameters only if they have a value.
        $queryParams = @{}

        if ($page) { $queryParams["page"] = $page }
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
        
        # Search for the service by ServiceName.
        foreach ($service in $response) {
            if ($service.name -eq $ServiceName) {
                $foundService = $service
                break
            }
        }
        
        # If no items are returned, break out of the loop.
        if (($response | Measure-Object).Count -eq 0) { break }

        $page++
    } while (-not $foundService)
    
    if (-not $foundService) {
        Write-Warning "Service with name '$ServiceName' not found."
    }

    return $foundService
}