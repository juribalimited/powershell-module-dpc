function Invoke-JuribaAPIBulkImportUserFeedDataTableDiff{
    <#
    .Synopsis
    Synchronizes a user import feed from a data table using a differential load.

    .Description
    Takes a System.Data.Datatable object with the columns required for the DwAPI User. Compares
    the table to the existing feed items by uniqueIdentifier, POSTs new rows, PATCHes existing rows
    and deletes feed items no longer present in the source data.

    .Parameter Instance
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for and used.

    .Parameter ImportId
    The id of the User feed to be used.

    .Parameter DPCUserDataTable
    [System.Data.DataTable] Data table containing the fields required to insert data into the DW User API.

    .Parameter DPCUserAppDataTable
    [System.Data.DataTable] Data table containing the columns UserUniqueIdentifier, appUniqueIdentifier and
    appDistHierId (DPC 5.13 and earlier) or appUniversalDataImportId (DPC 5.14 and later).

    .Outputs
    Output type [string]
    Text confirming the number of rows processed.

    .Example
    # Synchronize the named user feed using the provided data table.
    Invoke-JuribaAPIBulkImportUserFeedDataTableDiff -Instance $Instance -APIKey $APIKey -DPCUserDataTable $dtJuribaUserImport -ImportId $UserImportID
    #>

    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,
        [Parameter(Mandatory=$True)]
        [System.Data.DataTable]$DPCUserDataTable,
        [Parameter(Mandatory=$false)]
        [System.Data.DataTable]$DPCUserAppDataTable,
        [Parameter(Mandatory=$True)]
        [string]$APIKey,
        [parameter(Mandatory=$False)]
        [string]$FeedName = $null,
        [parameter(Mandatory=$False)]
        [string]$ImportId = $null,
        [parameter(Mandatory=$False)]
        [array]$CustomFields = @(),
        [parameter(Mandatory=$False)]
        [array]$Properties = @(),
        [parameter(Mandatory=$False)]
        [int]$BatchSize = 500
    )

    if (-not $ImportId)
    {
        if (-not $FeedName)
        {
            throw "Either -ImportId or -FeedName must be provided."
        }
        try{
            $feedIds = @((Get-JuribaImportUserFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName -ErrorAction Stop).id)
        }
        catch {
            throw "User feed lookup failed. $_"
        }
        if ($feedIds.Count -eq 0 -or -not $feedIds[0])
        {
            throw "User feed not found by name '$FeedName'."
        }
        if ($feedIds.Count -gt 1)
        {
            throw "Multiple import feeds matched name '$FeedName'. Pass -ImportId to disambiguate."
        }
        $ImportId = [string]$feedIds[0]
    }

    try{
        [version]$juribaVersion = (Invoke-JuribaWebRequestWithRetry -Uri "$Instance/apiv1").Content.Replace('Hello World - ','')
        if($juribaVersion.Major -le 5 -and $juribaVersion.Minor -le 13){$APIVersion = 1}else{$APIVersion = 2}
        write-debug "$(get-date -format 'o') ProductVersion: $($juribaVersion.Major).$($juribaVersion.Minor) - API Version: $APIVersion"
    }catch{
        throw "API Version Check failed. $_"
    }

    if ($null -ne $DPCUserAppDataTable -and $DPCUserAppDataTable.Rows.Count -gt 0)
    {
        $requiredAppColumn = if ($APIVersion -eq 1) { 'appDistHierId' } else { 'appUniversalDataImportId' }
        if (-not $DPCUserAppDataTable.Columns.Contains($requiredAppColumn))
        {
            throw "DPCUserAppDataTable must contain an '$requiredAppColumn' column when the DPC instance uses API version $APIVersion."
        }
    }

    write-debug "$(get-date -format 'o') Existing uniqueIdentifiers - Get Page 1"

    if ($APIVersion -eq 1)
    {
        $uri = '{0}/apiv2/imports/users/{1}/items?fields=uniqueIdentifier,lastUpdated&order=uniqueIdentifier&limit=1000' -f $Instance,$ImportId
    }
    else{
        $uri = '{0}/apiv2/imports/{1}/users?fields=uniqueIdentifier,lastUpdated&order=uniqueIdentifier&limit=1000' -f $Instance,$ImportId
    }

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
        $dtExistingUsers = ConvertTo-DataTable ($threadSafeDictionary.GetEnumerator()  | select-Object -Property @{Name='uniqueIdentifier';Expression={$_.key}})
        write-debug "$(get-date -format 'o') Existing uniqueIdentifiers - Written to table"
        $dtPostPatch = Merge-DataTable -primaryTable $DPCUserDataTable -secondaryTable $dtExistingUsers -LeftjoinKeyProperty "UniqueIdentifier" -rightjoinkeyproperty "uniqueIdentifier" -AddColumn @{"uniqueIdentifier"="ExistsInSource"}
        write-debug "$(get-date -format 'o') Existing uniqueIdentifiers - Post & Patch Rows calculated"
        $dtDelete = Merge-DataTable -primaryTable $dtExistingUsers -secondaryTable $DPCUserDataTable -LeftjoinKeyProperty "uniqueIdentifier" -rightjoinkeyproperty "UniqueIdentifier" -AddColumn @{"UniqueIdentifier"="ExistsInSource"}
        write-debug "$(get-date -format 'o') Existing uniqueIdentifiers - Delete Rows calculated"
    }
    else {
        $dtPostPatch = $DPCUserDataTable.Copy()
        $dtPostPatch.Columns.Add("ExistsInSource") | Out-Null
    }
    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    if ($APIVersion -eq 1)
    {
        $uri = '{0}/apiv2/imports/users/{1}/items/$bulk' -f $Instance, $ImportId
    }
    else{
        $uri = '{0}/apiv2/imports/{1}/users/$bulk' -f $Instance, $ImportId
    }

    $ExcludeProperty = @("ItemArray", "Table", "RowError", "RowState", "HasErrors","ExistsInSource","DataView","RowVersion","Row","IsNew","IsEdit","Error","RequireRegisteredTypes")
    if ($CustomFields.count -gt 0) {$ExcludeProperty += $CustomFields}
    if ($Properties.count -gt 0) {$ExcludeProperty += $Properties}

    $dvUserData = New-Object System.Data.DataView($dtPostPatch)
    for($i=0;$i -le 1;$i++)
    {
        if ($i -eq 0) #Post
        {
            $Method = 'Post'
            $dvUserData.RowFilter ="ISNULL(ExistsInSource,'') = ''" #"Len(ExistsInSource) = 0"
        } else {
            $Method = 'Patch'
            $dvUserData.RowFilter ="Len(ExistsInSource) > 0"
        }
        $dtUserData = $dvUserData.ToTable()
        Write-Debug "$(Get-date -Format 'o'):Starting upload loop - i=: $i - Method: $Method - ObjectCount: $($dtUserData.Rows.Count)"

        $BulkUploadObject = @()
        $RowCount = 0
        $errorFoundInUpload = $false

        $stopwatch =  [system.diagnostics.stopwatch]::StartNew()
        $stopwatch.Stop()

        foreach($Row in $dtUserData){
            $RowCount++
            $Body = $null
            $Body = $Row | Select-Object *,CustomFieldValues,applications,Properties -ExcludeProperty $ExcludeProperty

            if($body.PSObject.Properties['Owner'] -and $body.Owner -eq ''){$body.PSObject.Properties.Remove('Owner')}

            $applications = @()
            if ($null -ne $DPCUserAppDataTable -and $DPCUserAppDataTable.Rows.Count -gt 0)
            {
                $rowUid = ([string]$Row.uniqueIdentifier).Replace("'","''")
                foreach($App in $DPCUserAppDataTable.select("userUniqueIdentifier='$rowUid'"))
                {
                    if ($APIVersion -eq 1)
                    {
                        $applications += @{"appDistHierId"=$App.appDistHierId;"applicationBusinessKey"=$App.AppUniqueIdentifier;"entitled"=$true}
                    }
                    else{
                        $applications += @{"applicationUniversalDataImportId"=$App.appUniversalDataImportId;"applicationBusinessKey"=$App.AppUniqueIdentifier;"entitled"=$true}
                    }
                }
            }
            $Body.applications = $applications

            $CustomFieldValues = @()
            $CFVtemplate = 'if ($Row.### -ne [dbnull]::value)
                            {
                                $CustomField = @{
                                    name = "###"
                                    value = $Row.###
                                }
                                $CustomField
                            }'

            foreach($CustomFieldName in $CustomFields)
            {
                $ScriptBlock = $null
                $ScriptBlock = $CFVtemplate.Replace('###',$CustomFieldName)
                $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)
                $CustomFieldValues += . $ScriptBlock
            }
            $Body.CustomFieldValues = $CustomFieldValues

            $PropertyEntries = @()
            $PropertyTemplate = 'if ($Row.### -ne [dbnull]::value)
            {
                $PropertyEntry = @{
                    name = "###"
                    value = @($Row.###)
                }
                $PropertyEntry
            }'
            foreach($Property in $Properties)
            {
                $ScriptBlock = $null
                $ScriptBlock=$PropertyTemplate.Replace('###',$Property)
                $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)
                $PropertyEntries += . $ScriptBlock
            }
            $Body.Properties = $PropertyEntries

            $BulkUploadObject += $Body

            if ($BulkUploadObject.Count -eq $BatchSize -or $RowCount -eq $dtUserData.Rows.Count)
            {
                $JSONBody = ConvertTo-Json -Depth 10 -InputObject $BulkUploadObject
                $ByteArrayBody = [System.Text.Encoding]::UTF8.GetBytes($JSONBody)
                try{
                    $stopwatch.Start()
                    $APIResponse = Invoke-JuribaWebRequestWithRetry -Headers $Postheaders -Uri $uri -Method $Method -Body $ByteArrayBody -UseRestMethod
                    foreach($RowResult in $APIResponse)
                    {
                        if(($Method -eq 'Post' -and $RowResult.status -ne 201) -or ($Method -eq 'Patch' -and $RowResult.status -ne 204))
                        {
                            write-debug "$(Get-date -Format 'o'):Method-$Method Record-$($RowResult.data.uniqueIdentifier) Status-$($RowResult.status) $($RowResult.details)"
                            #All rows here should be accepted, thus, if there are any failures, end the upload process.
                            $errorFoundInUpload=$true
                        }
                    }
                    $stopwatch.Stop()
                    write-debug "$(Get-date -Format 'o'):Method $Method - $RowCount rows processed. Total Upload: $($stopwatch.ElapsedMilliseconds)ms - Speed: $([math]::Round($RowCount / ($stopwatch.ElapsedMilliseconds / 1000)))/s"
                }catch{
                    $timeNow = (Get-date -Format 'o')
                    write-error "$timeNow;$_"
                    $errorFoundInUpload = $true
                }finally{
                    if ($errorFoundInUpload)
                    {
                        Throw "Errors found in upload. Re-run after enabling debug messages (`$debugPreference = 'Continue')"
                    }
                }
                $BulkUploadObject = @()
            }
        }
    }

    if ($null -ne $dtDelete)
    {
        $stopwatch.Reset()
        $dvUserDelete   = New-Object System.Data.DataView($dtDelete)
        $dvUserDelete.RowFilter ="ISNULL(ExistsInSource,'') = ''"
        $deleteArray = @()
        $RowCount=0
        $Method = "Delete"
        if($dvUserDelete.count -eq 1 -and $dvUserDelete[0].uniqueIdentifier -eq '#NULL#')
        {
            write-debug "Rows to delete: 0"
        }else{
            write-debug "Rows to delete: $($dvUserDelete.Count)"
        }

        foreach($row in $dvUserDelete)
        {
            if($row.uniqueIdentifier -eq '#NULL#'){continue}
            $RowCount++
            if ($APIVersion -eq 1)
            {
                $deleteArray += "/imports/users/{0}/items/{1}" -f $ImportId,$row.UniqueIdentifier
            }
            else{
                $deleteArray += "/imports/{0}/users/{1}" -f $ImportId,$row.UniqueIdentifier
            }
            if ($deleteArray.Count -eq $BatchSize -or $RowCount -eq $dvUserDelete.Count)
            {
                $JSONBody = $deleteArray | ConvertTo-Json -Depth 10
                $ByteArrayBody = [System.Text.Encoding]::UTF8.GetBytes($JSONBody)
                try{
                    $stopwatch.Start()
                    $DeleteResponse = Invoke-JuribaWebRequestWithRetry -Headers $Postheaders -Uri $uri -Method $Method -Body $ByteArrayBody -UseRestMethod
                    $stopwatch.Stop()
                    foreach($RowResult in $DeleteResponse)
                    {
                        if(($Method -eq 'Delete' -and $RowResult.status -ne 204))
                        {
                            write-debug "$(Get-date -Format 'o'):Method-$Method Record-$($RowResult.data) Status-$($RowResult.status) $($RowResult.details)"
                            #All rows here should be accepted, thus, if there are any failures, end the upload process.
                            $errorFoundInUpload=$true
                        }
                    }
                    write-debug "$(Get-date -Format 'o'):Method $Method - $RowCount rows processed. Total Upload: $($stopwatch.ElapsedMilliseconds)ms"
                }catch{
                    $timeNow = (Get-date -Format 'o')
                    write-error "$timeNow;$_"
                    $errorFoundInUpload = $true
                }finally{
                    if ($errorFoundInUpload)
                    {
                        Throw "Errors found in upload. Re-run after enabling debug messages (`$debugPreference = 'Continue')"
                    }
                }
                $deleteArray = @()
            }
        }
    }

    Return ("{0} users processed" -f $DPCUserDataTable.Rows.Count)
}
