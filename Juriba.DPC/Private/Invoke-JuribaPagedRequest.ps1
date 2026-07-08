function Invoke-JuribaPagedRequest {
    <#
        .SYNOPSIS
        Internal helper. Performs a GET request and, when the response is paged
        (indicated by the X-Pagination response header), retrieves all remaining
        pages and returns the combined, parsed result set.

        .DESCRIPTION
        Fetches the first page, reads totalPages from the X-Pagination header and
        then pulls pages 2..N. On PowerShell 7+ the remaining pages are pulled in
        parallel (throttled by ThrottleLimit); on Windows PowerShell 5.1 it falls
        back to sequential paging. Transient failures (HTTP 429 and 5xx) are
        retried with a short backoff.

        Returns the combined array of parsed JSON objects across all pages. The
        caller is responsible for any InfoLevel / property selection. Errors are
        allowed to propagate so each calling function can apply its own catch
        semantics (e.g. treating 404 as "not found").

        .PARAMETER Uri
        The fully-formed request URI for the first page. May or may not already
        contain a query string; the page parameter is appended with the correct
        separator (? or &).

        .PARAMETER Headers
        Request headers, including the x-api-key.

        .PARAMETER ContentType
        Optional. Defaults to "application/json".

        .PARAMETER ThrottleLimit
        Optional. Maximum number of pages to request concurrently on PowerShell
        7+. Defaults to 8. Set to 1 to force sequential paging.
    #>
    [CmdletBinding()]
    [OutputType([Object[]])]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        [Parameter(Mandatory=$true)]
        [hashtable]$Headers,
        [Parameter(Mandatory=$false)]
        [string]$ContentType = "application/json",
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 64)]
        [int]$ThrottleLimit = 8
    )

    $items = [System.Collections.Generic.List[object]]::new()

    # Parses a page's raw content and appends any objects to the result list.
    # '[]' and empty content are treated as "no items" so we never add a $null.
    $addContent = {
        param($content)
        if (-not [string]::IsNullOrWhiteSpace($content) -and $content.Trim() -ne '[]') {
            foreach ($object in @($content | ConvertFrom-Json)) {
                $items.Add($object)
            }
        }
    }

    $firstPage = Invoke-JuribaWebRequestWithRetry -Uri $Uri -Headers $Headers -ContentType $ContentType
    & $addContent $firstPage.Content

    # Not paged - return the single page as-is.
    if (-not $firstPage.Headers.ContainsKey("X-Pagination")) {
        return $items.ToArray()
    }

    $totalPages = ($firstPage.Headers."X-Pagination" | ConvertFrom-Json).totalPages
    if ($totalPages -le 1) {
        return $items.ToArray()
    }

    # The first-page URI may or may not already carry a query string.
    $separator = if ($Uri.Contains("?")) { "&" } else { "?" }
    $remainingPages = 2..$totalPages

    if ($PSVersionTable.PSVersion.Major -ge 7 -and $ThrottleLimit -gt 1) {
        # PowerShell 7+: pull the remaining pages in parallel. Parallel runspaces
        # cannot see module-private functions, so the retry logic is inlined here
        # to mirror Invoke-JuribaWebRequestWithRetry.
        $pages = $remainingPages | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
            $pagedUri = "{0}{1}page={2}" -f $using:Uri, $using:separator, $_
            $attempt = 0
            $maxAttempts = 4
            while ($true) {
                try {
                    $response = Invoke-WebRequest -Uri $pagedUri -Method GET -Headers $using:Headers -ContentType $using:ContentType
                    break
                }
                catch {
                    $status = $null
                    $responseProperty = $_.Exception.psobject.Properties['Response']
                    if ($responseProperty -and $responseProperty.Value) {
                        $status = [int]$responseProperty.Value.StatusCode
                    }
                    $attempt++
                    $retryable = ($status -eq 429) -or ($null -ne $status -and $status -ge 500)
                    if ($attempt -ge $maxAttempts -or -not $retryable) { throw }
                    Start-Sleep -Milliseconds ([int](200 * [math]::Pow(2, $attempt)))
                }
            }
            # Emit page number alongside content so results can be re-ordered.
            [pscustomobject]@{ Page = $_; Content = $response.Content }
        }
        # Parallel results arrive out of order; re-sort to keep output deterministic.
        foreach ($page in ($pages | Sort-Object Page)) {
            & $addContent $page.Content
        }
    }
    else {
        # Windows PowerShell 5.1 (or ThrottleLimit = 1): sequential paging.
        foreach ($page in $remainingPages) {
            $pagedUri = "{0}{1}page={2}" -f $Uri, $separator, $page
            $pagedResult = Invoke-JuribaWebRequestWithRetry -Uri $pagedUri -Headers $Headers -ContentType $ContentType
            & $addContent $pagedResult.Content
        }
    }

    return $items.ToArray()
}
