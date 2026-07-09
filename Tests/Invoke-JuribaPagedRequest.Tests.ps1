#requires -Version 7
# Pester v5 tests for the private paging helpers Invoke-JuribaPagedRequest and
# Invoke-JuribaWebRequestWithRetry.
#
# These are NOT run by the current CI (which only runs PSScriptAnalyzer) and are
# not part of the published module. Run locally with Pester 5+:
#   Invoke-Pester .\Tests\Invoke-JuribaPagedRequest.Tests.ps1

BeforeAll {
    Set-StrictMode -Version Latest
    $privateDir = Join-Path $PSScriptRoot '..\Juriba.DPC\Private'
    . (Resolve-Path (Join-Path $privateDir 'Invoke-JuribaWebRequestWithRetry.ps1'))
    . (Resolve-Path (Join-Path $privateDir 'Invoke-JuribaPagedRequest.ps1'))

    # Spins up a throwaway HttpListener that pages a 3-page result set. The
    # 'mode' controls how page 2 behaves so we can exercise the error paths.
    #   ok         - every page succeeds
    #   notfound2  - page 2 always returns 404 (non-retryable)
    #   transient2 - page 2 returns 500 twice then succeeds (retryable)
    function Start-TestListener {
        param([int]$Port, [string]$Mode = 'ok')
        $prefix = "http://localhost:$Port/"
        $listener = [System.Net.HttpListener]::new()
        $listener.Prefixes.Add($prefix)
        $listener.Start()
        $job = Start-ThreadJob -ScriptBlock {
            param($listener, $mode)
            $page2hits = 0
            while ($true) {
                try { $ctx = $listener.GetContext() } catch { break }
                $q = $ctx.Request.Url.Query
                $page = 1; if ($q -match 'page=(\d+)') { $page = [int]$Matches[1] }
                $fail = $false; $code = 200
                if ($page -eq 2) {
                    if ($mode -eq 'notfound2') { $fail = $true; $code = 404 }
                    elseif ($mode -eq 'transient2') { $page2hits++; if ($page2hits -le 2) { $fail = $true; $code = 500 } }
                }
                $ctx.Response.ContentType = 'application/json'
                if ($fail) {
                    $ctx.Response.StatusCode = $code
                    $b = [System.Text.Encoding]::UTF8.GetBytes('error')
                } else {
                    if ($page -eq 1) { $ctx.Response.Headers.Add('X-Pagination', '{"totalPages":3}') }
                    $b = [System.Text.Encoding]::UTF8.GetBytes(('[{{"id":{0}}}]' -f $page))
                }
                $ctx.Response.OutputStream.Write($b, 0, $b.Length)
                $ctx.Response.Close()
            }
        } -ArgumentList $listener, $Mode
        [pscustomobject]@{ Listener = $listener; Job = $job; Base = ($prefix + 'items?limit=50') }
    }

    function Stop-TestListener {
        param($Context)
        $Context.Listener.Stop(); $Context.Listener.Close()
        $Context.Job | Remove-Job -Force
    }
}

Describe 'Invoke-JuribaWebRequestWithRetry' {
    It 'returns the response for a successful request' {
        Mock -CommandName Invoke-WebRequest -MockWith { [pscustomobject]@{ Content = '[{"id":1}]' } }
        $r = Invoke-JuribaWebRequestWithRetry -Uri 'https://x/y' -Headers @{}
        $r.Content | Should -Be '[{"id":1}]'
    }

    It 'does NOT retry a non-transient error (404) and rethrows it' {
        $script:calls = 0
        Mock -CommandName Invoke-WebRequest -MockWith {
            $script:calls++
            $resp = [pscustomobject]@{ StatusCode = [System.Net.HttpStatusCode]::NotFound }
            $ex = [System.Exception]::new('Not Found')
            $ex | Add-Member -NotePropertyName Response -NotePropertyValue $resp
            throw $ex
        }
        { Invoke-JuribaWebRequestWithRetry -Uri 'https://x/y' -Headers @{} } | Should -Throw
        $script:calls | Should -Be 1
    }

    It 'retries a transient error (500) up to MaxAttempts' {
        $script:calls = 0
        Mock -CommandName Invoke-WebRequest -MockWith {
            $script:calls++
            $resp = [pscustomobject]@{ StatusCode = [System.Net.HttpStatusCode]::InternalServerError }
            $ex = [System.Exception]::new('Server Error')
            $ex | Add-Member -NotePropertyName Response -NotePropertyValue $resp
            throw $ex
        }
        { Invoke-JuribaWebRequestWithRetry -Uri 'https://x/y' -Headers @{} -MaxAttempts 3 } | Should -Throw
        $script:calls | Should -Be 3
    }
}

Describe 'Invoke-JuribaPagedRequest (mocked, sequential)' {
    It 'aggregates all pages when the response is paged' {
        Mock -CommandName Invoke-JuribaWebRequestWithRetry -MockWith {
            $page = 1; if ($Uri -match 'page=(\d+)') { $page = [int]$Matches[1] }
            $headers = @{}
            if ($page -eq 1) { $headers['X-Pagination'] = '{"totalPages":3}' }
            [pscustomobject]@{
                Content = ('[{{"UniqueIdentifier":"p{0}"}}]' -f $page)
                Headers = $headers
            }
        }
        $r = Invoke-JuribaPagedRequest -Uri 'https://x/items?limit=50' -Headers @{} -ThrottleLimit 1
        $r.Count | Should -Be 3
        ($r.UniqueIdentifier | Sort-Object) -join ',' | Should -Be 'p1,p2,p3'
    }

    It 'returns a single page when there is no X-Pagination header' {
        Mock -CommandName Invoke-JuribaWebRequestWithRetry -MockWith {
            [pscustomobject]@{ Content = '[{"UniqueIdentifier":"only"}]'; Headers = @{} }
        }
        $r = Invoke-JuribaPagedRequest -Uri 'https://x/items?limit=50' -Headers @{} -ThrottleLimit 1
        @($r).Count | Should -Be 1
        $r.UniqueIdentifier | Should -Be 'only'
    }

    It 'treats an empty result set ([]) as zero items' {
        Mock -CommandName Invoke-JuribaWebRequestWithRetry -MockWith {
            [pscustomobject]@{ Content = '[]'; Headers = @{} }
        }
        $r = Invoke-JuribaPagedRequest -Uri 'https://x/items?limit=50' -Headers @{} -ThrottleLimit 1
        @($r).Count | Should -Be 0
    }

    It 'appends the page parameter with the correct separator' {
        $script:requested = [System.Collections.Generic.List[string]]::new()
        Mock -CommandName Invoke-JuribaWebRequestWithRetry -MockWith {
            $script:requested.Add($Uri)
            $page = 1; if ($Uri -match 'page=(\d+)') { $page = [int]$Matches[1] }
            $headers = @{}
            if ($page -eq 1) { $headers['X-Pagination'] = '{"totalPages":2}' }
            [pscustomobject]@{ Content = ('[{{"id":{0}}}]' -f $page); Headers = $headers }
        }
        # base URI without a query string -> ?page=2
        Invoke-JuribaPagedRequest -Uri 'https://x/tasks' -Headers @{} -ThrottleLimit 1 | Out-Null
        $script:requested[1] | Should -Be 'https://x/tasks?page=2'
    }
}

Describe 'Invoke-JuribaPagedRequest (parallel, live HttpListener)' {
    It 'pulls all pages in parallel on the happy path' {
        $ctx = Start-TestListener -Port 9201 -Mode 'ok'
        try {
            $r = Invoke-JuribaPagedRequest -Uri $ctx.Base -Headers @{} -ThrottleLimit 8
            $r.Count | Should -Be 3
            ($r.id | Sort-Object) -join ',' | Should -Be '1,2,3'
        } finally { Stop-TestListener $ctx }
    }

    It 'falls back to sequential and surfaces a faithful 404 when a page persistently fails' {
        $ctx = Start-TestListener -Port 9202 -Mode 'notfound2'
        try {
            $status = $null
            try { Invoke-JuribaPagedRequest -Uri $ctx.Base -Headers @{} -ThrottleLimit 8 }
            catch { $status = $_.Exception.Response.StatusCode.Value__ }
            $status | Should -Be 404
        } finally { Stop-TestListener $ctx }
    }

    It 'recovers a transient failure via the sequential fallback' {
        $ctx = Start-TestListener -Port 9203 -Mode 'transient2'
        try {
            $r = Invoke-JuribaPagedRequest -Uri $ctx.Base -Headers @{} -ThrottleLimit 8
            $r.Count | Should -Be 3
            ($r.id | Sort-Object) -join ',' | Should -Be '1,2,3'
        } finally { Stop-TestListener $ctx }
    }
}
