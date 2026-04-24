function Invoke-JuribaAPIBulkImportGroupFeedDataTableDiff {

    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$Instance,

        [Parameter(Mandatory)]
        [System.Data.DataTable]$DPCGroupDataTable,

        [Parameter(Mandatory)]
        [System.Data.DataTable]$DPCGroupMemberTable,

        [Parameter(Mandatory)]
        [string]$APIKey,

        [Parameter()]
        [string]$FeedName,

        [Parameter()]
        [string]$ImportId,

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
            [int]$Depth = 10,
            [bool]$AsyncMode = $false
        )

        $json  = ConvertTo-Json -Depth $Depth -InputObject $Payload
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

        if (-not $AsyncMode) {
            return Invoke-RestMethod `
                -Uri $Uri `
                -Method $Method `
                -Headers $Headers `
                -ContentType "application/json" `
                -Body $bytes `
                -MaximumRetryCount 3 `
                -RetryIntervalSec 20
        }

        # Async mode (API v2 bulk async pattern): POST/PATCH returns Location header with job URL
        # DELETE should not be async (caller strips ?async)
        $resp = Invoke-WebRequest `
            -Uri $Uri `
            -Method $Method `
            -Headers $Headers `
            -ContentType "application/json" `
            -Body $bytes `
            -MaximumRetryCount 3 `
            -RetryIntervalSec 20

        if (-not $resp.Headers.Location) {
            throw "Async bulk request did not return a Location header."
        }

        $jobUri = $resp.Headers.Location
        do {
            Start-Sleep -Milliseconds 500
            $job = Invoke-RestMethod -Uri $jobUri -Headers @{ 'X-API-KEY' = $Headers['X-API-KEY'] }
        } while ($job.status -eq "InProgress")

        if ($job.status -eq "Failed") {
            throw "Async bulk job failed. requestId=$($job.requestId) error=$($job.error)"
        }

        # Normalize to match the non-async contract: return row results
        return $job.result
    }

    
        function Build-GroupBodyFromRow {
            param(
                [Parameter(Mandatory)][System.Data.DataRow]$Row,
                [Parameter(Mandatory)][System.Data.DataTable]$MemberTable,
                [Parameter(Mandatory)][string]$ImportId,
                [Parameter(Mandatory)][int]$APIVersion,
                [string[]]$Properties
            )

            $propertySet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($p in @($Properties)) {
                $t = if ($p) { $p.Trim() } else { $null }
                if ($t) { [void]$propertySet.Add($t) }
            }


        function Get-TypedValue {
            param(
                [Parameter(Mandatory)][System.Data.DataRow]$Row,
                [Parameter(Mandatory)][System.Data.DataColumn]$Col
            )

            $val = $Row[$Col.ColumnName]
            if ($val -eq [DBNull]::Value) { return $null }

            if ($Col.DataType -eq [bool]) { return [bool]$val }
            return $val
        }

        function Ensure-ArrayValue {
            param([Parameter(Mandatory)]$Value)

            # If it's already an array/collection (but not string), pass it through
            if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
                return @($Value)
            }

            # Otherwise wrap single value
            return @($Value)
        }

        function Normalize-ObjectType {
            param([Parameter(Mandatory)][string]$ObjectType)

            # Generic normalization: trim + TitleCase first letter (no hard-coded values)
            $t = $ObjectType.Trim()
            if ($t.Length -eq 0) { return $t }
            return ($t.Substring(0,1).ToUpperInvariant() + $t.Substring(1))
        }

        $body = @{}

        # -------------------------
        # Core group fields (top-level)
        # Exclude Property columns from main body
        # -------------------------
        foreach ($col in $Row.Table.Columns) {
            $name = $col.ColumnName

            if ($propertySet.Contains($name))    { continue }

            $typed = Get-TypedValue -Row $Row -Col $col
            if ($null -ne $typed) {
                $body[$name] = $typed
            }
        }

        # -------------------------
        # Members (from DPCGroupMemberTable)
        # Match: MemberTable.groupUniqueIdentifier == Row.UniqueIdentifier
        # -------------------------
        $members = @()

        if ($MemberTable -and $MemberTable.Rows.Count -gt 0 -and $Row.Table.Columns.Contains("UniqueIdentifier")) {
            $gid = $Row["UniqueIdentifier"]
            if ($gid -ne [DBNull]::Value -and $gid) {

                $filterGid = Escape-DataTableFilterValue ([string]$gid)

                foreach ($m in $MemberTable.Select("groupUniqueIdentifier='$filterGid'")) {

                    # Use member-provided importId if present, else fall back to the feed importId
                    $memberImportId = $ImportId
                    if ($MemberTable.Columns.Contains("importid")) {
                        $raw = $m["importid"]
                        if ($raw -ne [DBNull]::Value -and $raw) { $memberImportId = [string]$raw }
                    }

                    $members += @{
                        uniqueIdentifier = $m.memberUniqueIdentifier
                        importId         = $memberImportId
                        objectType       = $m.objecttype
                        isPrimary        = [bool]$m.isprimary
                    }
                }
            }
        }

        $body["members"] = $members

        # -------------------------
        # Properties
        # -------------------------
        $props = @()
        foreach ($prop in @($Properties)) {
            $propName = $prop
            if ($propName) { $propName = $propName.Trim() }
            if (-not $propName) { continue }

            if ($Row.Table.Columns.Contains($propName)) {
                $col = $Row.Table.Columns[$propName]
                $typed = Get-TypedValue -Row $Row -Col $col
                if ($null -ne $typed) {
                    $props += @{ name = $propName; value = @($typed) }
                }
            }
        }
        $body["Properties"] = $props

        return $body
    }

    function Get-ExistingGroupIdsPaged {
        param(
            [Parameter(Mandatory)][string]$FirstPageUri,
            [Parameter(Mandatory)][hashtable]$Headers
        )

        $dict = [System.Collections.Concurrent.ConcurrentDictionary[string,byte]]::new()

        Write-Debug "$(Get-Date -Format o) Existing uniqueIdentifiers - Get Page 1"

        $resp1 = Invoke-WebRequest -Uri $FirstPageUri -Headers $Headers -Method GET
        $content1 = [System.Text.Encoding]::UTF8.GetString($resp1.Content)

        if ($content1 -and $content1 -ne '[]') {
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
            # Fallback paging if no X-Pagination header
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

        # IMPORTANT: prevent enumeration so caller always receives the HashSet object, even if empty
        return ,$set
    }

    # ------------------------
    # Validate required columns
    # ------------------------
    if (-not $DPCGroupDataTable.Columns.Contains("UniqueIdentifier")) {
        throw "DPCGroupDataTable must contain a 'UniqueIdentifier' column."
    }

    $requiredMemberCols = @('groupUniqueIdentifier','memberUniqueIdentifier','importid','objecttype','isprimary')
    foreach ($c in $requiredMemberCols) {
        if (-not $DPCGroupMemberTable.Columns.Contains($c)) {
            throw "DPCGroupMemberTable must contain column '$c'."
        }
    }

    # ------------------------
    # Resolve ImportId
    # ------------------------
    if (-not $ImportId) {
        if (-not $FeedName) {
            throw "Group feed name or ImportId must be specified"
        }
        $ImportId = (Get-JuribaImportGroup -Instance $Instance -ApiKey $APIKey -Name $FeedName).id
        if (-not $ImportId) { throw "Group feed not found by name or ID" }
    }

    # ------------------------
    # Detect API version (<=5.13 is API v1 shape)
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
        $listUri = "{0}/apiv2/imports/groups/{1}/items?fields=uniqueIdentifier&order=uniqueIdentifier&limit=1000" -f $Instance, $ImportId
        $bulkUri = "{0}/apiv2/imports/groups/{1}/items/`$bulk" -f $Instance, $ImportId
    }
    else {
        $listUri = "{0}/apiv2/imports/{1}/groups?fields=uniqueIdentifier&order=uniqueIdentifier&limit=1000" -f $Instance, $ImportId
        $bulkUri = "{0}/apiv2/imports/{1}/groups/`$bulk" -f $Instance, $ImportId
        if ($Async) { $bulkUri += "?async" }
    }

    # ------------------------
    # Get ALL existing uniqueIdentifiers (paged)
    # ------------------------
    $existingSet = Get-ExistingGroupIdsPaged -FirstPageUri $listUri -Headers $getHeaders
    Write-Debug "$(Get-Date -Format o) Existing uniqueIdentifiers - Retrieved: $($existingSet.Count)"

    # ------------------------
    # Build SOURCE set + dedupe rows (last row wins)
    # ------------------------
    $sourceSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $rowById   = @{}  # uid -> DataRow (last wins)

    foreach ($r in $DPCGroupDataTable.Rows) {
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
            Write-Debug "$(Get-Date -Format o) Skipping $method � no rows to process"
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

            $batch += (Build-GroupBodyFromRow `
                -Row $row `
                -MemberTable $DPCGroupMemberTable `
                -ImportId $ImportId `
                -APIVersion $APIVersion `
                -Properties $Properties)

            if ($batch.Count -eq $BatchSize -or $rowCount -eq $rowTotal) {

                if ($batch.Count -eq 0) { continue }

                try {
                    $stopwatch.Start()

                    $useAsync = ($APIVersion -eq 2 -and $Async -and ($method -in @("POST","PATCH")))
                    $apiResponse = Invoke-BulkRequest -Uri $bulkUri -Method $method -Headers $bulkHeaders -Payload $batch -AsyncMode:$useAsync

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
                $deleteArray += "/imports/groups/{0}/items/{1}" -f $ImportId, $id
            }
            else {
                $deleteArray += "/imports/{0}/groups/{1}" -f $ImportId, $id
            }

            if ($deleteArray.Count -eq $BatchSize -or $rowCount -eq $deleteTotal) {

                if ($deleteArray.Count -eq 0) { continue }

                try {
                    $stopwatch.Start()
                    $deleteResponse = Invoke-BulkRequest -Uri $deleteBulkUri -Method "DELETE" -Headers $bulkHeaders -Payload $deleteArray -AsyncMode:$false
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

    return "Group feed import completed successfully"
}