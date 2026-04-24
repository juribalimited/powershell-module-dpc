function Invoke-JuribaAPIBulkImportApplicationFeedDataTableDiff {

    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$Instance,

        [Parameter(Mandatory)]
        [System.Data.DataTable]$DPCApplicationDataTable,

        [Parameter()]
        [System.Data.DataTable]$DPCDeviceAppDataTable,

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

    function Get-WebResponseContentString {
        param([Parameter(Mandatory)]$Response)

        if ($Response.Content -is [byte[]]) {
            return [System.Text.Encoding]::UTF8.GetString($Response.Content)
        }
        return [string]$Response.Content
    }

    function ConvertFrom-JsonSafeDataArray {
        param([Parameter(Mandatory)][string]$JsonText)

        # Supports either { data: [...] } or a plain [...]
        try {
            $obj = $JsonText | ConvertFrom-Json
            if ($null -eq $obj) { return @() }

            if ($obj.PSObject.Properties.Name -contains 'data') {
                return @($obj.data)
            }

            if ($obj -is [System.Collections.IEnumerable]) {
                return @($obj)
            }

            return @()
        }
        catch {
            return @()
        }
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

    function Get-ColumnNameInsensitive {
        param(
            [Parameter(Mandatory)][System.Data.DataTable]$Table,
            [Parameter(Mandatory)][string]$Name
        )
        foreach ($c in $Table.Columns) {
            if ($c.ColumnName -ieq $Name) { return $c.ColumnName }
        }
        return $null
    }

    function Build-ApplicationBodyFromRow {
        param(
            [Parameter(Mandatory)][System.Data.DataRow]$Row,
            [Parameter()][hashtable]$DevicesByAppId,
            [string[]]$CustomFields,
            [string[]]$Properties
        )

        # Build lookup sets for fast exclusion
        $customFieldSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($cf in $CustomFields) { [void]$customFieldSet.Add($cf) }

        $propertySet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($p in $Properties) { [void]$propertySet.Add($p) }

        $body = @{}

        # ------------------------------------------------------------------
        # Core application fields ONLY (exclude CustomFields / Properties)
        # ------------------------------------------------------------------
        foreach ($col in $Row.Table.Columns) {
            $name = $col.ColumnName

            if ($customFieldSet.Contains($name)) { continue }
            if ($propertySet.Contains($name))    { continue }

            $val = $Row[$name]
            if ($val -ne [DBNull]::Value) {
                $body[$name] = $val
            }
        }

        # Remove Owner if present but empty (matches User/Device style)
        if ($body.ContainsKey("Owner") -and [string]::IsNullOrWhiteSpace([string]$body["Owner"])) {
            $body.Remove("Owner")
        }

        # -------------------------
        # Devices relationship
        # -------------------------
        $devices = @()
        if ($DevicesByAppId -and $Row.Table.Columns.Contains("UniqueIdentifier")) {
            $appId = [string]$Row["UniqueIdentifier"]
            if ($DevicesByAppId.ContainsKey($appId)) {
                $devices = $DevicesByAppId[$appId]
            }
        }
        $body["devices"] = $devices

        # -------------------------
        # CustomFieldValues
        # -------------------------
        $cfv = @()
        foreach ($field in $CustomFields) {
            if ($Row.Table.Columns.Contains($field)) {
                $val = $Row[$field]
                if ($val -ne [DBNull]::Value) {
                    $cfv += @{ name = $field; value = $val }
                }
            }
        }
        $body["CustomFieldValues"] = $cfv

        # -------------------------
        # Properties
        # -------------------------
        $props = @()
        foreach ($prop in $Properties) {
            if ($Row.Table.Columns.Contains($prop)) {
                $val = $Row[$prop]
                if ($val -ne [DBNull]::Value) {
                    $props += @{ name = $prop; value = @($val) }
                }
            }
        }
        $body["Properties"] = $props

        return $body
    }

    function Get-ExistingApplicationIdsPaged {
        param(
            [Parameter(Mandatory)][string]$FirstPageUri,
            [Parameter(Mandatory)][hashtable]$Headers
        )

        $dict = [System.Collections.Concurrent.ConcurrentDictionary[string,byte]]::new()

        Write-Debug "$(Get-Date -Format o) Existing uniqueIdentifiers - Get Page 1"

        $resp1    = Invoke-WebRequest -Uri $FirstPageUri -Headers $Headers -Method GET
        $content1 = Get-WebResponseContentString -Response $resp1

        if ($content1 -and $content1 -ne '[]') {
            $data1 = ConvertFrom-JsonSafeDataArray -JsonText $content1
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
                        $u   = $_
                        $hdr = $using:Headers
                        $d   = $using:dict

                        $tries = 0
                        do {
                            try {
                                $r = Invoke-WebRequest -Uri $u -Headers $hdr -Method GET
                                $c = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }

                                if ($c -and $c -ne '[]') {
                                    $obj = $null
                                    try { $obj = $c | ConvertFrom-Json } catch { $obj = $null }

                                    $data = @()
                                    if ($obj -and ($obj.PSObject.Properties.Name -contains 'data')) { $data = @($obj.data) }
                                    elseif ($obj -is [System.Collections.IEnumerable]) { $data = @($obj) }

                                    foreach ($e in @($data)) {
                                        if ($e.uniqueIdentifier) { $d.TryAdd([string]$e.uniqueIdentifier, 0) | Out-Null }
                                    }
                                }
                                break
                            }
                            catch {
                                $tries++
                                if ($tries -ge 3) { throw }
                                Start-Sleep -Seconds 2
                            }
                        } while ($true)
                    } -ThrottleLimit 10
                }
                else {
                    foreach ($u in $pageUris) {
                        $r = Invoke-WebRequest -Uri $u -Headers $Headers -Method GET
                        $c = Get-WebResponseContentString -Response $r
                        if ($c -and $c -ne '[]') {
                            $data = ConvertFrom-JsonSafeDataArray -JsonText $c
                            foreach ($e in @($data)) {
                                if ($e.uniqueIdentifier) { $dict.TryAdd([string]$e.uniqueIdentifier, 0) | Out-Null }
                            }
                        }
                    }
                }
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
            throw "Application feed name or ImportId must be specified"
        }
        $ImportId = (Get-JuribaImportApplicationFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName).id
        if (-not $ImportId) { throw "Application feed not found by name or ID" }
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
        $listUri = "{0}/apiv2/imports/applications/{1}/items?fields=uniqueIdentifier&order=uniqueIdentifier&limit=1000" -f $Instance, $ImportId
        $bulkUri = "{0}/apiv2/imports/applications/{1}/items/`$bulk" -f $Instance, $ImportId
    }
    else {
        $listUri = "{0}/apiv2/imports/{1}/applications?fields=uniqueIdentifier&order=uniqueIdentifier&limit=1000" -f $Instance, $ImportId
        $bulkUri = "{0}/apiv2/imports/{1}/applications/`$bulk" -f $Instance, $ImportId
        if ($Async) { $bulkUri += "?async" }
    }

    # ------------------------
    # Validate source table has UniqueIdentifier
    # ------------------------
    if (-not $DPCApplicationDataTable.Columns.Contains("UniqueIdentifier")) {
        throw "DPCApplicationDataTable must contain a 'UniqueIdentifier' column."
    }

    # ------------------------
    # Build app->devices lookup (optional but much faster than DataTable.Select per row)
    # ------------------------
    $devicesByAppId = @{}
    if ($DPCDeviceAppDataTable -and $DPCDeviceAppDataTable.Rows.Count -gt 0) {

        $colApp = Get-ColumnNameInsensitive -Table $DPCDeviceAppDataTable -Name "appUniqueIdentifier"
        $colDev = Get-ColumnNameInsensitive -Table $DPCDeviceAppDataTable -Name "DeviceUniqueIdentifier"
        if (-not $colDev) { $colDev = Get-ColumnNameInsensitive -Table $DPCDeviceAppDataTable -Name "deviceUniqueIdentifier" }
        $colImp = Get-ColumnNameInsensitive -Table $DPCDeviceAppDataTable -Name "deviceImportID"

        if ($colApp -and $colDev -and $colImp) {
            foreach ($r in $DPCDeviceAppDataTable.Rows) {
                $a = $r[$colApp]
                $d = $r[$colDev]
                $i = $r[$colImp]
                if ($a -eq [DBNull]::Value -or $d -eq [DBNull]::Value -or $i -eq [DBNull]::Value) { continue }

                $appId = [string]$a
                if (-not $devicesByAppId.ContainsKey($appId)) {
                    $devicesByAppId[$appId] = New-Object System.Collections.Generic.List[object]
                }

                $devicesByAppId[$appId].Add(@{
                    device    = "/imports/$i/devices/$d"
                    entitled  = $true
                    installed = $true
                })
            }

            # Convert List -> array for serialization stability
            foreach ($k in @($devicesByAppId.Keys)) {
                $devicesByAppId[$k] = $devicesByAppId[$k].ToArray()
            }
        }
    }

    # ------------------------
    # Get ALL existing uniqueIdentifiers (paged)
    # ------------------------
    $existingSet = Get-ExistingApplicationIdsPaged -FirstPageUri $listUri -Headers $getHeaders
    Write-Debug "$(Get-Date -Format o) Existing uniqueIdentifiers - Retrieved: $($existingSet.Count)"

    # ------------------------
    # Build SOURCE set + dedupe rows (last row wins)
    # ------------------------
    $sourceSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $rowById   = @{}  # uid -> DataRow (last wins)

    foreach ($r in $DPCApplicationDataTable.Rows) {
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

        $batch = [System.Collections.Generic.List[object]]::new()
        $rowCount = 0
        $errorFound = $false

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $stopwatch.Stop()

        foreach ($row in @($rows)) {
            $rowCount++

            $body = Build-ApplicationBodyFromRow `
                        -Row $row `
                        -DevicesByAppId $devicesByAppId `
                        -CustomFields $CustomFields `
                        -Properties $Properties

            $batch.Add($body)

            if ($batch.Count -eq $BatchSize -or $rowCount -eq $rowTotal) {

                try {
                    Write-Debug "$(Get-Date -Format o) Sending $method batch size: $($batch.Count)"
                    $stopwatch.Start()
                    $apiResponse = Invoke-BulkRequest -Uri $bulkUri -Method $method -Headers $bulkHeaders -Payload $batch.ToArray()
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

                $batch.Clear()
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

        $deleteArray = [System.Collections.Generic.List[string]]::new()
        $rowCount = 0
        $errorFound = $false

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $stopwatch.Stop()

        $deleteTotal = @($deleteIds).Count

        foreach ($id in @($deleteIds)) {
            $rowCount++

            if ($APIVersion -eq 1) {
                $deleteArray.Add(("/imports/applications/{0}/items/{1}" -f $ImportId, $id))
            }
            else {
                $deleteArray.Add(("/imports/{0}/applications/{1}" -f $ImportId, $id))
            }

            if ($deleteArray.Count -eq $BatchSize -or $rowCount -eq $deleteTotal) {

                try {
                    Write-Debug "$(Get-Date -Format o) Sending DELETE batch size: $($deleteArray.Count)"
                    $stopwatch.Start()
                    $deleteResponse = Invoke-BulkRequest -Uri $deleteBulkUri -Method "DELETE" -Headers $bulkHeaders -Payload $deleteArray.ToArray()
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

                $deleteArray.Clear()
            }
        }
    }

    return "Application feed import completed successfully"
}