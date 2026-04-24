function Invoke-JuribaAPIBulkImportUserFeedDataTableDiff {

    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$Instance,

        [Parameter(Mandatory)]
        [System.Data.DataTable]$DPCUserDataTable,

        [Parameter()]
        [System.Data.DataTable]$DPCUserAppDataTable,

        [Parameter(Mandatory)]
        [string]$APIKey,

        [Parameter()]
        [string]$FeedName,

        [Parameter()]
        [string]$ImportId,

        [Parameter()]
        [string[]]$CustomFields = @(),

        [Parameter()]
        [string[]]$Properties = @(),

        [Parameter()]
        [int]$BatchSize = 500,

        [Parameter()]
        [bool]$Async = $false
    )

    # ------------------------
    # Local helpers
    # ------------------------
    function Escape-DataTableFilterValue([string]$Value) {
        if ($null -eq $Value) { return "" }
        return $Value.Replace("'", "''")
    }

    function Invoke-BulkRequest {
        param(
            [Parameter(Mandatory)][string]$Uri,
            [Parameter(Mandatory)][ValidateSet("POST","PATCH","DELETE")][string]$Method,
            [Parameter(Mandatory)][hashtable]$Headers,
            [Parameter(Mandatory)][object]$Payload,
            [int]$Depth = 10
        )

        $json  = ConvertTo-Json -Depth $Depth -InputObject $Payload
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

        Invoke-RestMethod `
            -Uri $Uri `
            -Method $Method `
            -Headers $Headers `
            -ContentType "application/json" `
            -Body $bytes `
            -MaximumRetryCount 3 `
            -RetryIntervalSec 20
    }

    function Build-UserBodyFromRow {
        param(
            [Parameter(Mandatory)][System.Data.DataRow]$Row,
            [Parameter()][System.Data.DataTable]$AppTable,
            [Parameter(Mandatory)][int]$APIVersion,
            [string[]]$CustomFields,
            [string[]]$Properties
        )

        # Build lookup sets for fast exclusion
        $customFieldSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($cf in $CustomFields) { [void]$customFieldSet.Add($cf) }

        $propertySet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($p in $Properties) { [void]$propertySet.Add($p) }

        # Helper: returns a value typed according to the DataColumn datatype
        function Get-TypedValue {
            param(
                [Parameter(Mandatory)][System.Data.DataRow]$Row,
                [Parameter(Mandatory)][string]$ColumnName
            )

            $val = $Row[$ColumnName]
            if ($val -eq [DBNull]::Value -and $col.DataType -ne [bool]) { return $null }

            $col = $Row.Table.Columns[$ColumnName]
            if ($null -eq $col) { return $val }

            if ($col.DataType -eq [bool]) { return [bool]$val }

            return $val
        }

        $body = @{}

        # ------------------------------------------------------------------
        # Core user fields ONLY (exclude CustomFields / Properties)
        # ------------------------------------------------------------------
        foreach ($col in $Row.Table.Columns) {
            $name = $col.ColumnName

            if ($customFieldSet.Contains($name)) { continue }
            if ($propertySet.Contains($name))    { continue }

            $typed = Get-TypedValue -Row $Row -ColumnName $name
            if ($null -ne $typed) {
                $body[$name] = $typed
            }
        }

        # Remove Owner if present but empty
        if ($body.ContainsKey("Owner") -and [string]::IsNullOrWhiteSpace([string]$body["Owner"])) {
            $body.Remove("Owner")
        }

        # -------------------------
        # Applications
        # -------------------------
        $apps = @()
        if ($AppTable -and $AppTable.Rows.Count -gt 0 -and $Row.Table.Columns.Contains("UniqueIdentifier")) {

            $uid = $Row["UniqueIdentifier"]
            if ($uid -ne [DBNull]::Value -and $uid) {

                $filterUid = Escape-DataTableFilterValue ([string]$uid)

                foreach ($app in $AppTable.Select("userUniqueIdentifier='$filterUid'")) {
                    if ($APIVersion -eq 1) {
                        $apps += @{
                            appDistHierId          = $app.appDistHierId
                            applicationBusinessKey = $app.appUniqueIdentifier
                            entitled               = $true
                        }
                    }
                    else {
                        $apps += @{
                            applicationUniversalDataImportId = $app.appUniversalDataImportId
                            applicationBusinessKey           = $app.appUniqueIdentifier
                            entitled                         = $true
                        }
                    }
                }
            }
        }
        $body["applications"] = $apps

        # -------------------------
        # CustomFieldValues (typed)
        # -------------------------
        $cfv = @()
        foreach ($field in $CustomFields) {
            if ($Row.Table.Columns.Contains($field)) {
                $typed = Get-TypedValue -Row $Row -ColumnName $field
                if ($null -ne $typed) {
                    $cfv += @{ name = $field; value = $typed }
                }
            }
        }
        $body["CustomFieldValues"] = $cfv

        # -------------------------
        # Properties (typed)
        # -------------------------
        $props = @()
        foreach ($prop in $Properties) {
            if ($Row.Table.Columns.Contains($prop)) {
                $typed = Get-TypedValue -Row $Row -ColumnName $prop
                if ($null -ne $typed) {
                    $props += @{ name = $prop; value = @($typed) }
                }
            }
        }
        $body["Properties"] = $props

        return $body
    }


    function Get-ExistingUserIdsPaged {
        param(
            [Parameter(Mandatory)][string]$FirstPageUri,
            [Parameter(Mandatory)][hashtable]$Headers
        )

        $dict = [System.Collections.Concurrent.ConcurrentDictionary[string,byte]]::new()

        Write-Debug "$(Get-Date -Format o) Existing uniqueIdentifiers - Get Page 1"

        $resp1 = Invoke-WebRequest -Uri $FirstPageUri -Headers $Headers -Method GET
        $content1 = [System.Text.Encoding]::UTF8.GetString($resp1.Content)

        if ($content1 -ne '[]') {
            $data1 = @()
            try { $data1 = ($content1 | ConvertFrom-Json).data } catch { $data1 = @() }

            foreach ($e in @($data1)) {
                if ($e.uniqueIdentifier) { $dict.TryAdd([string]$e.uniqueIdentifier, 0) | Out-Null }
            }
        }

        if ($resp1.Headers.ContainsKey("X-Pagination")) {
            $totalPages = ($resp1.Headers."X-Pagination" | ConvertFrom-Json).totalPages
            if ($totalPages -gt 1) {

                $pageUris = for ($p = 2; $p -le $totalPages; $p++) { "$FirstPageUri&page=$p" }
                Write-Debug "$(Get-Date -Format o) Existing uniqueIdentifiers - Getting pages 2..$totalPages"

                if ($PSVersionTable.PSVersion.Major -ge 7) {
                    $pageUris | ForEach-Object -Parallel {
                        $u = $_
                        $hdr = $using:Headers
                        $d = $using:dict

                        $ok = $false
                        $tries = 0
                        do {
                            try {
                                $r = Invoke-WebRequest -Uri $u -Headers $hdr -Method GET
                                $c = [System.Text.Encoding]::UTF8.GetString($r.Content)

                                if ($c -and $c -ne '[]') {
                                    $data = @()
                                    try { $data = ($c | ConvertFrom-Json).data } catch { $data = @() }
                                    foreach ($e in @($data)) {
                                        if ($e.uniqueIdentifier) { $d.TryAdd([string]$e.uniqueIdentifier, 0) | Out-Null }
                                    }
                                }
                                $ok = $true
                            }
                            catch {
                                $tries++
                                if ($tries -ge 3) { throw }
                                Start-Sleep -Seconds 2
                            }
                        } while (-not $ok)
                    } -ThrottleLimit 10
                }
                else {
                    foreach ($u in $pageUris) {
                        $r = Invoke-WebRequest -Uri $u -Headers $Headers -Method GET
                        $c = [System.Text.Encoding]::UTF8.GetString($r.Content)
                        if ($c -and $c -ne '[]') {
                            $data = @()
                            try { $data = ($c | ConvertFrom-Json).data } catch { $data = @() }
                            foreach ($e in @($data)) {
                                if ($e.uniqueIdentifier) { $dict.TryAdd([string]$e.uniqueIdentifier, 0) | Out-Null }
                            }
                        }
                    }
                }
            }
        }
        else {
            $page = 2
            while ($true) {
                $u = "$FirstPageUri&page=$page"
                $r = Invoke-WebRequest -Uri $u -Headers $Headers -Method GET
                $c = [System.Text.Encoding]::UTF8.GetString($r.Content)

                $data = @()
                try { $data = ($c | ConvertFrom-Json).data } catch { $data = @() }

                if (@($data).Count -eq 0) { break }

                foreach ($e in @($data)) {
                    if ($e.uniqueIdentifier) { $dict.TryAdd([string]$e.uniqueIdentifier, 0) | Out-Null }
                }
                $page++
            }
        }

        $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($k in $dict.Keys) { [void]$set.Add($k) }

        return ,$set
    }

    # ------------------------
    # Resolve ImportId
    # ------------------------
    if (-not $ImportId) {
        if (-not $FeedName) {
            throw "User feed name or ImportId must be specified"
        }
        $ImportId = (Get-JuribaImportUserFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName).id
        if (-not $ImportId) { throw "User feed not found by name or ID" }
    }

    # ------------------------
    # Detect API version properly (<=5.13 is API v1 shape)
    # ------------------------
    [version]$juribaVersion = (Invoke-WebRequest -Uri "$Instance/apiv1").Content.Replace('Hello World - ', '')
    $APIVersion = if (
        ($juribaVersion.Major -lt 5) -or
        ($juribaVersion.Major -eq 5 -and $juribaVersion.Minor -le 13)
    ) { 1 } else { 2 }

    Write-Debug "$(Get-Date -Format o) ProductVersion: $juribaVersion - API Version: $APIVersion"

    # ------------------------
    # Headers
    # ------------------------
    $getHeaders  = @{ 'x-api-key' = $APIKey; 'Accept' = 'application/vnd.juriba.dashworks+json' }
    $bulkHeaders = @{ 'X-API-KEY' = $APIKey; 'content-type' = 'application/json' }

    # ------------------------
    # URIs
    # ------------------------
    if ($APIVersion -eq 1) {
        $listUri = "{0}/apiv2/imports/users/{1}/items?fields=uniqueIdentifier&order=uniqueIdentifier&limit=1000" -f $Instance, $ImportId
        $bulkUri = "{0}/apiv2/imports/users/{1}/items/`$bulk" -f $Instance, $ImportId
    }
    else {
        $listUri = "{0}/apiv2/imports/{1}/users?fields=uniqueIdentifier&order=uniqueIdentifier&limit=1000" -f $Instance, $ImportId
        $bulkUri = "{0}/apiv2/imports/{1}/users/`$bulk" -f $Instance, $ImportId
        if ($Async) { $bulkUri += "?async" }
    }

    # ------------------------
    # Validate source table has UniqueIdentifier
    # ------------------------
    if (-not $DPCUserDataTable.Columns.Contains("UniqueIdentifier")) {
        throw "DPCUserDataTable must contain a 'UniqueIdentifier' column."
    }

    # ------------------------
    # Get ALL existing uniqueIdentifiers (paged)
    # ------------------------
    $existingSet = Get-ExistingUserIdsPaged -FirstPageUri $listUri -Headers $getHeaders
    Write-Debug "$(Get-Date -Format o) Existing uniqueIdentifiers - Retrieved: $($existingSet.Count)"

    # ------------------------
    # Build SOURCE set + dedupe rows (last row wins)
    # ------------------------
    $sourceSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $rowById   = @{}  # uid -> DataRow (last wins)

    foreach ($r in $DPCUserDataTable.Rows) {
        $uid = $r["UniqueIdentifier"]
        if ($uid -eq [DBNull]::Value -or -not $uid) { continue }
        $uidS = [string]$uid
        [void]$sourceSet.Add($uidS)
        $rowById[$uidS] = $r
    }

    # ------------------------
    # Split into POST and PATCH
    # ------------------------
    $postRows  = @()
    $patchRows = @()

    foreach ($uid in $rowById.Keys) {
        if ($existingSet.Contains($uid)) { $patchRows += $rowById[$uid] }
        else { $postRows += $rowById[$uid] }
    }

    # ------------------------
    # BULK POST / PATCH
    # ------------------------
    foreach ($method in @("POST","PATCH")) {

        $rows = if ($method -eq "POST") { $postRows } else { $patchRows }

        
        if (-not $rows -or @($rows).Count -eq 0) {
                Write-Debug "$(Get-Date -Format FileDate) Skipping $method - no rows to process"
                continue
            }
        
        $rowTotal = @($rows).Count
        Write-Debug "$(Get-Date -Format o) Starting $method - ObjectCount: $rowTotal"

        $batch = @()
        $rowCount = 0
        $errorFound = $false
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $stopwatch.Stop()

        foreach ($row in @($rows)) {
            $rowCount++

            $batch += (Build-UserBodyFromRow -Row $row -AppTable $DPCUserAppDataTable -APIVersion $APIVersion -CustomFields $CustomFields -Properties $Properties)

            if ($batch.Count -eq $BatchSize -or $rowCount -eq $rowTotal) {

                try {
                    $stopwatch.Start()
                    $apiResponse = Invoke-BulkRequest -Uri $bulkUri -Method $method -Headers $bulkHeaders -Payload $batch
                    $stopwatch.Stop()

                    foreach ($rr in @($apiResponse)) {
                        if (($method -eq "POST"  -and $rr.status -ne 201) -or
                            ($method -eq "PATCH" -and $rr.status -ne 204)) {
                            Write-Debug "$(Get-Date -Format o):Method-$method Record-$($rr.data.uniqueIdentifier) Status-$($rr.status) $($rr.details)"
                            $errorFound = $true
                        }
                    }

                    Write-Debug "$(Get-Date -Format o):Method $method - $rowCount rows processed. Total Upload: $($stopwatch.ElapsedMilliseconds)ms"
                }
                catch {
                    Write-Error "$(Get-Date -Format o);$_"
                    $errorFound = $true
                }
                finally {
                    if ($errorFound) {
                        throw "Errors found in upload. Re-run after enabling debug messages (`$debugPreference = 'Continue')"
                    }
                }

                $batch = @()
            }
        }
    }

    # ------------------------
    # DELETE (existing - source)
    # ------------------------
    $deleteIds = @()
    foreach ($eid in $existingSet) {
        if (-not $sourceSet.Contains($eid)) { $deleteIds += $eid }
    }

    Write-Debug "$(Get-Date -Format o) Rows to delete: $(@($deleteIds).Count)"

    if (@($deleteIds).Count -gt 0) {

        # DELETE should not be async even if Async is true
        $deleteBulkUri = $bulkUri -replace '\?async$',''

        $deleteArray = @()
        $rowCount = 0
        $errorFound = $false

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $stopwatch.Stop()

        $deleteTotal = @($deleteIds).Count

        foreach ($id in @($deleteIds)) {
            $rowCount++

            if ($APIVersion -eq 1) {
                $deleteArray += "/imports/users/{0}/items/{1}" -f $ImportId, $id
            }
            else {
                $deleteArray += "/imports/{0}/users/{1}" -f $ImportId, $id
            }

            if ($deleteArray.Count -eq $BatchSize -or $rowCount -eq $deleteTotal) {

                try {
                    $stopwatch.Start()
                    $deleteResponse = Invoke-BulkRequest -Uri $deleteBulkUri -Method "DELETE" -Headers $bulkHeaders -Payload $deleteArray
                    $stopwatch.Stop()

                    foreach ($rr in @($deleteResponse)) {
                        if ($rr.status -ne 204) {
                            Write-Debug "$(Get-Date -Format o):Method-DELETE Record-$($rr.data) Status-$($rr.status) $($rr.details)"
                            $errorFound = $true
                        }
                    }

                    Write-Debug "$(Get-Date -Format o):Method DELETE - $rowCount rows processed. Total Upload: $($stopwatch.ElapsedMilliseconds)ms"
                }
                catch {
                    Write-Error "$(Get-Date -Format o);$_"
                    $errorFound = $true
                }
                finally {
                    if ($errorFound) {
                        throw "Errors found in delete. Re-run after enabling debug messages (`$debugPreference = 'Continue')"
                    }
                }

                $deleteArray = @()
            }
        }
    }

    return "User feed import completed successfully"
}