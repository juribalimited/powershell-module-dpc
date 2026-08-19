function Invoke-JuribaAPIImportLocationFeedDataTable{
    <#
    .Synopsis
    Synchronizes a location import feed from a data table using a differential load.

    .Description
    Takes a System.Data.Datatable object with the columns required for the Juriba DPC location import API.
    Compares the table to the existing feed items by uniqueIdentifier, POSTs new rows, PATCHes existing rows
    and deletes feed items no longer present in the source data.
    Uses the universal imports API and therefore requires Juriba DPC 5.14 or later.

    .Parameter Instance
    The URI to the Juriba DPC instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for and used.

    .Parameter ImportId
    The id of the location feed to be used.

    .Parameter DPCLocationDataTable
    [System.Data.DataTable] Data table containing the fields required to insert data into the Juriba DPC location import API.

    .Outputs
    Output type [string]
    Text confirming the number of rows processed.

    .Example
    # Synchronize the location feed with the given id from the data table.
    Invoke-JuribaAPIImportLocationFeedDataTable -Instance $Instance -DPCLocationDataTable $dtJuribaLocationImport -ImportId $LocationImportID -APIKey $APIKey
    #>

    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,

        [Parameter(Mandatory=$True)]
        [System.Data.DataTable]$DPCLocationDataTable,

        [Parameter(Mandatory=$True)]
        [string]$APIKey,

        [parameter(Mandatory=$False)]
        [string]$FeedName = $null,

        [parameter(Mandatory=$False)]
        [string]$ImportId
    )

    if (-not $ImportId)
    {
        if (-not $FeedName)
        {
            throw "Either -ImportId or -FeedName must be provided."
        }
        try{
            $feedIds = @((Get-JuribaImportLocationFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName -ErrorAction Stop).id)
        }
        catch {
            throw "Location feed lookup failed. $_"
        }
        if ($feedIds.Count -eq 0 -or -not $feedIds[0])
        {
            throw "Location feed not found by name '$FeedName'."
        }
        if ($feedIds.Count -gt 1)
        {
            throw "Multiple import feeds matched name '$FeedName'. Pass -ImportId to disambiguate."
        }
        $ImportId = [string]$feedIds[0]
    }

    write-debug "$(get-date -format 'o') Existing uniqueIdentifiers - Get Page 1"

    $uri = '{0}/apiv2/imports/{1}/locations?fields=uniqueIdentifier,lastUpdated&order=uniqueIdentifier&limit=1000' -f $Instance,$ImportId

    $UIDheaders = @{'x-api-key' = $APIKey;'Accept'='application/vnd.juriba.dashworks+json'}

    # Capture the retry helper's definition so it can be injected into the
    # ForEach-Object -Parallel runspaces below (functions don't cross that boundary).
    $retryFunctionDef = ${function:Invoke-JuribaWebRequestWithRetry}.ToString()

    $response = Invoke-JuribaWebRequestWithRetry -Uri $uri -Headers $UIDheaders -Method Get

    $threadSafeDictionary = [System.Collections.Concurrent.ConcurrentDictionary[string,object]]::new()

    if([System.Text.Encoding]::UTF8.GetString($response.Content) -ne '[]')
    {
        write-debug "$(get-date -format 'o') Existing uniqueIdentifiers - Adding Page 1 to dictionary"
        Foreach($entry in ([System.Text.Encoding]::UTF8.GetString($response.Content) | ConvertFrom-Json).data)
        {
            $threadSafeDictionary.TryAdd($entry.uniqueIdentifier,$entry.lastUpdated) | Out-Null
        }

        if ($response.Headers.ContainsKey("X-Pagination")) {
            $totalPages = ($response.Headers."X-Pagination" | ConvertFrom-Json).totalPages
            $pagedUriArray=@()
            for ($page = 2; $page -le $totalPages; $page++) {
                $pagedUriArray += $uri + "&page={0}" -f $page
            }
            write-debug "$(get-date -format 'o') Existing uniqueIdentifiers - Geting next $totalPages pages"
            $pagedUriArray | ForEach-Object -Parallel {
                # Recreate the retry helper inside this runspace from the captured
                # definition, then use it so transient network failures on any page
                # are retried rather than aborting the run.
                ${function:Invoke-JuribaWebRequestWithRetry} = $using:retryFunctionDef
                $dict = $using:threadSafeDictionary
                $pagedUri = $_

                $pagedResult = Invoke-JuribaWebRequestWithRetry -Uri $pagedUri -Method Get -Headers $using:UIDheaders

                if ($pagedResult.length -gt 0)
                {
                    Foreach($entry in ([System.Text.Encoding]::UTF8.GetString($pagedResult.Content) | ConvertFrom-Json).data)
                    {
                        $dict.TryAdd($entry.uniqueIdentifier,$entry.lastUpdated) | Out-Null
                    }
                }
            } -ThrottleLimit 10
        }
    } else {
        $threadSafeDictionary.TryAdd('#NULL#','2000-01-01') | Out-Null
    }
    write-debug "$(get-date -format 'o') Existing uniqueIdentifiers - Data retrieved"

    $dtDelete = $null
    if ($threadSafeDictionary.Count -gt 0)
    {
        $dtExistingLocations = ConvertTo-DataTable ($threadSafeDictionary.GetEnumerator()  | select-Object -Property @{Name='uniqueIdentifier';Expression={$_.key}})
        write-debug "$(get-date -format 'o') Existing uniqueIdentifiers - Written to table"
        $dtPostPatch = Merge-DataTable -primaryTable $DPCLocationDataTable -secondaryTable $dtExistingLocations -LeftjoinKeyProperty "UniqueIdentifier" -rightjoinkeyproperty "uniqueIdentifier" -AddColumns @{"uniqueIdentifier"="ExistsInSource"}
        write-debug "$(get-date -format 'o') Existing uniqueIdentifiers - Post & Patch Rows calculated"
        $dtDelete = Merge-DataTable -primaryTable $dtExistingLocations -secondaryTable $DPCLocationDataTable -LeftjoinKeyProperty "uniqueIdentifier" -rightjoinkeyproperty "UniqueIdentifier" -AddColumns @{"UniqueIdentifier"="ExistsInSource"}
        write-debug "$(get-date -format 'o') Existing uniqueIdentifiers - Delete Rows calculated"
    }
    else {
        $dtPostPatch = $DPCLocationDataTable.Copy()
        $dtPostPatch.Columns.Add("ExistsInSource") | Out-Null
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = "{0}/apiv2/imports/{1}/locations/" -f $Instance, $ImportId
    $dvLocationData = New-Object System.Data.DataView($dtPostPatch)
    $failedRowCount = 0

    for($i=0;$i -le 1;$i++)
    {
        if ($i -eq 0) #Post
        {
            $Method = 'Post'
            $dvLocationData.RowFilter ="ISNULL(ExistsInSource,'') = ''"
        } else {
            $Method = 'Patch'
            $dvLocationData.RowFilter ="Len(ExistsInSource) > 0"
        }
        $stopwatch =  [system.diagnostics.stopwatch]::StartNew()
        $stopwatch.Stop()
        $uploadCount = 1
        foreach($Row in $dvLocationData) {
            $Body = $null
            $Body = $Row | Select-Object * -ExcludeProperty DataView,RowVersion,Row,IsNew,IsEdit,RequireRegisteredTypes,Error,ExistsInSource | ConvertTo-Json -Depth 10
            try{
                if ($Method -eq 'Patch') {$locationURI = $uri + $Row.uniqueIdentifier}else{$locationURI=$uri}
                $stopwatch.start()
                $apiReturn = Invoke-JuribaWebRequestWithRetry -Headers $Postheaders -Uri $locationURI -Method $Method -Body ([System.Text.Encoding]::UTF8.GetBytes($Body))
                $stopwatch.Stop()
                if (($Method -eq 'Post' -and $apiReturn.StatusCode -ne 201) -or ($Method -eq 'Patch' -and $apiReturn.StatusCode -ne 204))
                {
                    write-error "$Method returned $($apiReturn.StatusCode) : $($apiReturn.StatusDescription)"
                    $failedRowCount++
                }
            }catch{
                write-error "$Method failed for location '$($Row.uniqueIdentifier)': $_"
                $failedRowCount++
            }
            if ($uploadCount%10 -eq 0 -and $stopwatch.ElapsedMilliseconds -gt 0) {write-debug "$(Get-date -Format 'o'):Method $Method - $uploadCount rows processed. Total Upload: $($stopwatch.ElapsedMilliseconds)ms - Speed: $([math]::Round($uploadCount / ($stopwatch.ElapsedMilliseconds / 1000)))/s"}
            $uploadCount++
        }
        write-debug ("$(Get-date -Format 'o'):{0} locations {1}ed" -f $dvLocationData.Count,$method)
    }

    if ($null -ne $dtDelete)
    {
        $stopwatch =  [system.diagnostics.stopwatch]::StartNew()
        $stopwatch.Stop()
        $dvLocationDelete = New-Object System.Data.DataView($dtDelete)
        $dvLocationDelete.RowFilter = "ISNULL(ExistsInSource,'') = ''"
        $Method = 'Delete'
        if($dvLocationDelete.Count -eq 1 -and $dvLocationDelete[0].uniqueIdentifier -eq '#NULL#')
        {
            write-debug "$(get-date -format 'o') Rows to delete: 0"
        }else{
            write-debug "$(get-date -format 'o') Rows to delete: $($dvLocationDelete.Count)"
        }

        $uploadCount = 1
        $deletedCount = 0
        foreach($rowToDelete in $dvLocationDelete)
        {
            if($rowToDelete.uniqueIdentifier -eq '#NULL#'){continue}
            $deleteURI = "{0}/apiv2/imports/{1}/locations/{2}" -f $Instance, $ImportId, $rowToDelete.uniqueIdentifier
            try{
                $stopwatch.start()
                $apiReturn = Invoke-JuribaWebRequestWithRetry -Headers $Postheaders -Uri $deleteURI -Method $Method
                $stopwatch.Stop()
                if ($apiReturn.StatusCode -ne 204)
                {
                    write-error "$Method returned $($apiReturn.StatusCode) : $($apiReturn.StatusDescription)"
                    $failedRowCount++
                }else{
                    $deletedCount++
                }
            }catch{
                write-error "$Method failed for location '$($rowToDelete.uniqueIdentifier)': $_"
                $failedRowCount++
            }
            if ($uploadCount%10 -eq 0) {write-debug "$(Get-date -Format 'o'):Method $Method - $uploadCount rows processed. Total: $($stopwatch.ElapsedMilliseconds)ms"}
            $uploadCount++
        }
        write-debug ("$(Get-date -Format 'o'):{0} locations deleted" -f $deletedCount)
    }

    if ($failedRowCount -gt 0)
    {
        throw "$failedRowCount location row(s) failed to import or delete. Review the error output for details."
    }

    Return ("{0} locations processed" -f $DPCLocationDataTable.Rows.Count)
}
