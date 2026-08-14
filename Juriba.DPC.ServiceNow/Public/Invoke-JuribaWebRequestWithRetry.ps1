function Invoke-JuribaWebRequestWithRetry {
    <#
        .SYNOPSIS
        Performs an HTTP request with a short exponential backoff retry for
        transient failures. Works for any method (GET/POST/PATCH/DELETE/...).

        .DESCRIPTION
        Wraps Invoke-WebRequest (default) or Invoke-RestMethod (-UseRestMethod)
        and retries on transient conditions only:
          * No HTTP response at all - i.e. a timeout, dropped connection or DNS
            failure that threw before any status was returned. This is the case
            the built-in -MaximumRetryCount does NOT cover, and is exactly what a
            "temporarily broken network connection" looks like.
          * HTTP 408 (Request Timeout)
          * HTTP 429 (Too Many Requests) - honours Retry-After when supplied
          * HTTP 5xx (server errors)

        All other failures (e.g. 400/401/403/404) are re-thrown immediately so the
        caller can apply its own catch semantics. Backoff is exponential
        (400ms, 800ms, 1600ms, ...) capped at 30 seconds per wait.

        Returns the same object the underlying cmdlet would: a response object from
        Invoke-WebRequest, or the deserialised body from Invoke-RestMethod.

        .PARAMETER Uri
        The request URI.

        .PARAMETER Headers
        Request headers (e.g. x-api-key). Optional; defaults to empty.

        .PARAMETER Method
        HTTP method. Defaults to Get.

        .PARAMETER Body
        Optional request body (e.g. a UTF8 byte array of JSON) for writes.

        .PARAMETER ContentType
        Content-Type to send. Ignored if the caller already supplies a Content-Type
        header in -Headers (avoids the "appears in both" error on writes).
        Defaults to application/json.

        .PARAMETER MaxAttempts
        Total number of attempts before giving up. Defaults to 5. Raise this to ride
        out longer network outages.

        .PARAMETER TimeoutSec
        Per-request timeout. A hung socket throws after this and is then retried.
        Defaults to 300.

        .PARAMETER UseRestMethod
        Use Invoke-RestMethod (returns the deserialised body) instead of
        Invoke-WebRequest (returns the raw response object). Use this where the
        caller expects parsed output - e.g. drop-in for an existing Invoke-RestMethod
        call.

        .EXAMPLE
        $response = Invoke-JuribaWebRequestWithRetry -Uri $uri -Headers $UIDheaders

        .EXAMPLE
        $rows = Invoke-JuribaWebRequestWithRetry -Uri $uri -Headers $Postheaders -Method Post -Body $ByteArrayBody -UseRestMethod
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        [Parameter(Mandatory=$false)]
        [hashtable]$Headers = @{},
        [Parameter(Mandatory=$false)]
        [string]$Method = "Get",
        [Parameter(Mandatory=$false)]
        $Body,
        [Parameter(Mandatory=$false)]
        [string]$ContentType = "application/json",
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 10)]
        [int]$MaxAttempts = 5,
        [Parameter(Mandatory=$false)]
        [int]$TimeoutSec = 300,
        [Parameter(Mandatory=$false)]
        [switch]$UseRestMethod
    )

    # Only set ContentType when the caller hasn't already put one in Headers,
    # otherwise Invoke-WebRequest/-RestMethod errors that it appears in both.
    $hasContentTypeHeader = $false
    foreach ($headerKey in $Headers.Keys) {
        if ($headerKey -ieq "content-type") { $hasContentTypeHeader = $true; break }
    }

    $requestParams = @{
        Uri         = $Uri
        Method      = $Method
        Headers     = $Headers
        TimeoutSec  = $TimeoutSec
        ErrorAction = "Stop"
    }
    if (-not $hasContentTypeHeader) { $requestParams["ContentType"] = $ContentType }
    if ($PSBoundParameters.ContainsKey("Body")) { $requestParams["Body"] = $Body }

    $attempt = 0
    while ($true) {
        try {
            if ($UseRestMethod) {
                return Invoke-RestMethod @requestParams
            }
            else {
                return Invoke-WebRequest @requestParams
            }
        }
        catch {
            # Determine the HTTP status code without tripping StrictMode on
            # exceptions that have no Response property (e.g. timeouts, DNS failures).
            $status = $null
            $responseProperty = $_.Exception.psobject.Properties['Response']
            if ($responseProperty -and $responseProperty.Value) {
                $status = [int]$responseProperty.Value.StatusCode
            }

            $attempt++
            # Retry transient conditions only: no HTTP response ($status is $null ->
            # timeout / dropped connection / DNS failure), 408, 429 and 5xx.
            $retryable = ($null -eq $status) -or ($status -eq 408) -or ($status -eq 429) -or ($status -ge 500)
            if ($attempt -ge $MaxAttempts -or -not $retryable) {
                throw
            }

            # Exponential backoff (capped at 30s). Honour Retry-After (best effort)
            # when the server supplies it on a 429.
            $delayMs = [math]::Min([int](200 * [math]::Pow(2, $attempt)), 30000)
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
            Write-Debug "$(Get-Date -Format 'o') Request attempt $attempt failed (status: $status). Retrying in $delayMs ms. Uri: $Uri"
            Start-Sleep -Milliseconds $delayMs
        }
    }
}
