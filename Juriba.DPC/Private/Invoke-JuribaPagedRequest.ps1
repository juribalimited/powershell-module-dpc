function Invoke-JuribaPagedRequest {
    <#
        .SYNOPSIS
        Internal helper. Performs a GET request and, when the response is paged
        (indicated by the X-Pagination response header), retrieves all remaining
        pages and returns the combined, parsed result set.

        .DESCRIPTION
        Fetches the first page, reads totalPages from the X-Pagination header and
        then pulls pages 2..N. On PowerShell 7+ the remaining pages are pulled in
        parallel (throttled by ThrottleLimit). Each parallel page retries transient
        failures in place (see below), so a rate-limit response - including one
        provoked by the concurrent burst - is absorbed rather than aborting the
        batch. If a page still fails after retries (a non-transient error such as
        404/401) the helper falls back to the sequential path for pages 2..N so the
        caller receives a faithful terminating error (HTTP details are lost when an
        exception crosses the parallel runspace boundary). On Windows PowerShell
        5.1, or when ThrottleLimit is 1, paging is sequential.

        Transient failures (HTTP 429, 5xx and transport errors) are retried by
        Invoke-JuribaWebRequestWithRetry on both the parallel and sequential paths.

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
        # Fast path: pull the remaining pages in parallel. Each iteration reports
        # success or failure via a flag - -ErrorAction / -ErrorVariable are not
        # supported in the -Parallel parameter set.
        #
        # The retry helper is recreated inside each runspace (functions defined in
        # the module scope are not visible to -Parallel) so every parallel page
        # gets the same 429/5xx backoff and Retry-After handling as the sequential
        # path. This lets transient failures - including a 429 provoked by the
        # concurrent burst itself - self-heal in place rather than discarding all
        # parallel work and forcing a full sequential re-fetch. Only a persistent,
        # non-transient failure (e.g. 404/401) drops through to the fallback below.
        $retryFuncDef = ${function:Invoke-JuribaWebRequestWithRetry}.ToString()
        $pages = $remainingPages | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
            ${function:Invoke-JuribaWebRequestWithRetry} = $using:retryFuncDef
            $pagedUri = "{0}{1}page={2}" -f $using:Uri, $using:separator, $_
            try {
                $response = Invoke-JuribaWebRequestWithRetry -Uri $pagedUri -Headers $using:Headers -ContentType $using:ContentType
                # Emit page number alongside content so results can be re-ordered.
                [pscustomobject]@{ Page = $_; Content = $response.Content; Failed = $false }
            }
            catch {
                [pscustomobject]@{ Page = $_; Content = $null; Failed = $true }
            }
        }

        if (-not ($pages | Where-Object { $_.Failed })) {
            # Parallel results arrive out of order; re-sort for deterministic output.
            foreach ($page in ($pages | Sort-Object Page)) {
                & $addContent $page.Content
            }
            return $items.ToArray()
        }

        # A page failed even after in-runspace retries (i.e. a non-transient
        # error, or one that exhausted its retries). Discard the partial parallel
        # output (only page 1 has been added to $items) and rebuild pages 2..N
        # sequentially so the caller gets a faithful terminating error - HTTP
        # details are lost when an exception crosses the parallel runspace boundary.
        Write-Verbose "Parallel paging failed; retrying pages 2..$totalPages sequentially."
    }

    # Sequential paging: Windows PowerShell 5.1, ThrottleLimit = 1, or the
    # fallback after a parallel failure.
    foreach ($page in $remainingPages) {
        $pagedUri = "{0}{1}page={2}" -f $Uri, $separator, $page
        $pagedResult = Invoke-JuribaWebRequestWithRetry -Uri $pagedUri -Headers $Headers -ContentType $ContentType
        & $addContent $pagedResult.Content
    }

    return $items.ToArray()
}
