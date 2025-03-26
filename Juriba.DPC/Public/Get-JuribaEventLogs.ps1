function Get-JuribaEventLogs {
    <#
        .SYNOPSIS
        Retrieves event logs for a specific service run.

        .DESCRIPTION
        Queries the Juriba API to retrieve event logs from a specific run for a particular service.

        .PARAMETER Instance

        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER RunID

        The ID of the run you'd like to retrieve logs from.

        .PARAMETER Filter
        
        (Optional) A filter string to narrow down the results.

        .EXAMPLE

        PS> $ETLEvents = Get-JuribaEventLogs -Instance $Instance -APIKey $APIKey -RunID $LatestETLRun.runId -ErrorAction Stop
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,

        [Parameter(Mandatory = $false)]
        [string]$APIKey,

        [Parameter(Mandatory = $true)]
        [int]$RunID,

        [Parameter(Mandatory = $false)]
        [string]$Filter = ""
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    # Default filter if not provided.
    if (-not $Filter -or -not $Filter.Trim()) {
        $Filter = "and(eq(runId,%27$RunID%27),or(eq(levelId,%2750%27),eq(levelId,%2725%27),eq(levelId,%270%27),eq(levelId,%2775%27)))"
    }

    $baseUri = "$Instance/apiv2/event-logs"
    $headers = @{ "X-API-KEY" = $APIKey }
    $allResults = @()
    $startTime = Get-Date
    $page = 1

    try{
        do {
            if (((Get-Date) - $startTime).TotalMinutes -ge 15) {
                Write-Warning "Pagination timed out after 15 minutes."
                break
            }
            
            $queryParams = @{}
            if ($Filter -and $Filter.Trim()) { $queryParams["filter"] = $Filter }
            if ($page) { $queryParams["page"] = $page }
    
            $qsParts = @()
            foreach ($key in $queryParams.Keys) {
                $qsParts += "$key=$($queryParams[$key])"
            }
            $queryString = $qsParts -join "&"
            if ($queryString) { $uri = "$($baseUri)?$queryString" } else { $uri = $baseUri }
    
            Write-Verbose "Calling: $uri"
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET -ErrorAction Stop
    
            if ($response) {
                $allResults += $response
            }
    
            $page++
        } while ($response -and ($response | Measure-Object).Count -gt 0)
    } catch {
        Write-Error "Error calling API endpoint: $_"
    }
    
    return $allResults
}