function Invoke-JuribaWebRequestWithRetry {
    <#
        .SYNOPSIS
        Internal helper. Performs a GET via Invoke-WebRequest with a short
        exponential backoff retry for transient failures.

        .DESCRIPTION
        Retries on transient conditions: rate limiting (HTTP 429), server errors
        (HTTP 5xx) and transport-level failures that produced no HTTP response
        (e.g. a dropped connection). All other failures (e.g. 404) are re-thrown
        immediately so that calling functions can apply their own catch semantics.
        When a 429 response carries a Retry-After header its delay is honoured,
        otherwise an exponential backoff is used. Returns the raw response object
        from Invoke-WebRequest.

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
            # Retry rate limiting (429), server errors (5xx) and transport-level
            # failures (no HTTP response, so $status is $null).
            $retryable = ($null -eq $status) -or ($status -eq 429) -or ($status -ge 500)
            if ($attempt -ge $MaxAttempts -or -not $retryable) {
                throw
            }

            # Exponential backoff: 400ms, 800ms, 1600ms, ... Honour Retry-After
            # (best effort) when the server supplies it on a 429.
            $delayMs = [int](200 * [math]::Pow(2, $attempt))
            if ($status -eq 429 -and $responseProperty -and $responseProperty.Value) {
                try {
                    $retryAfter = $responseProperty.Value.Headers.RetryAfter
                    if ($retryAfter -and $retryAfter.Delta -and $retryAfter.Delta.TotalMilliseconds -gt 0) {
                        $delayMs = [int]$retryAfter.Delta.TotalMilliseconds
                    }
                }
                catch {
                    # Header shape differs across PowerShell editions; fall back to backoff.
                    Write-Verbose "Could not parse Retry-After header; using exponential backoff."
                }
            }
            Start-Sleep -Milliseconds $delayMs
        }
    }
}
