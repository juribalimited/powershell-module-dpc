function Invoke-JuribaWebRequestWithRetry {
    <#
        .SYNOPSIS
        Internal helper. Performs a GET via Invoke-WebRequest with a short
        exponential backoff retry for transient failures.

        .DESCRIPTION
        Retries only on transient responses (HTTP 429 and 5xx). All other
        failures (e.g. 404) are re-thrown immediately so that calling functions
        can apply their own catch semantics. Returns the raw response object from
        Invoke-WebRequest.

        .PARAMETER Uri
        The request URI.

        .PARAMETER Headers
        Request headers, including the x-api-key.

        .PARAMETER ContentType
        Optional. Defaults to "application/json".

        .PARAMETER MaxAttempts
        Optional. Total number of attempts before giving up. Defaults to 4.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        [Parameter(Mandatory=$true)]
        [hashtable]$Headers,
        [Parameter(Mandatory=$false)]
        [string]$ContentType = "application/json",
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 10)]
        [int]$MaxAttempts = 4
    )

    $attempt = 0
    while ($true) {
        try {
            return Invoke-WebRequest -Uri $Uri -Method GET -Headers $Headers -ContentType $ContentType
        }
        catch {
            # Determine the HTTP status code without tripping StrictMode on
            # exceptions that have no Response property (e.g. DNS failures).
            $status = $null
            $responseProperty = $_.Exception.psobject.Properties['Response']
            if ($responseProperty -and $responseProperty.Value) {
                $status = [int]$responseProperty.Value.StatusCode
            }

            $attempt++
            $retryable = ($status -eq 429) -or ($null -ne $status -and $status -ge 500)
            if ($attempt -ge $MaxAttempts -or -not $retryable) {
                throw
            }
            # Exponential backoff: 400ms, 800ms, 1600ms, ...
            Start-Sleep -Milliseconds ([int](200 * [math]::Pow(2, $attempt)))
        }
    }
}
