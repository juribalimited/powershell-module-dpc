function Invoke-JuribaAPIBulkImportUserFeedDataTableDiff{
    <#
    .Synopsis
    Loops a correctly formatted data table inserting all of the rows it contains.

    .Description
    Takes a System.Data.Datatable object with the columns required for the DwAPI User. Inserts these Users one at a time.

    .Parameter Instance
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a User with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for and used.

    .Parameter ImportId
    The id of the User feed to be used.

    .Parameter DPCUserDataTable
    [System.Data.DataTable] Data table containing the fields required to insert data into the DW User API.

    .Parameter DPCUserAppDataTable
    [System.Data.DataTable] Data table containing the columns UserUniqueIdentifier, appUniqueIdentifier & appDistHierId
    
    .Outputs
    Output type [string]
    Text confirming the number of rows to be inserted.

    .Example
    # Get the User feed id for the named feed.
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
        [int]$BatchSize = 500,
        [parameter(Mandatory=$False)]
        [boolean]$Async = $False
    )

    if (-not $ImportId)
    {
        if (-not $FeedName)
        {
            return 'User feed not found by name or ID'
        }
        try{
            $ImportId = (Get-JuribaImportUserFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName).id
        }
        catch {
            write-error "User feed lookup returned no results: $_"
            exit 1
        }
    }

    try{
        [version]$juribaVersion = (Invoke-WebRequest -Uri "$Instance/apiv1").Content.Replace('Hello World - ','')
        if($juribaVersion.Major -le 5 -and $juribaVersion.Minor -le 13){$APIVersion = 1}else{$APIVersion = 2}
        write-debug "$(get-date -format 'o') ProductVersion: $($juribaVersion.Major).$($juribaVersion.Minor) - API Version: $APIVersion"
    }catch{
        write-error "API Version Check returned: $_"
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

    $response = Invoke-WebRequest -uri $uri -Headers $UIDheaders -Method GET

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
                $dict = $using:threadSafeDictionary
                $pagedUri = $_
                $getComplete = $false
                $retryAttempts = 0
                Do{
                    try{
                        $pagedResult = Invoke-WebRequest -Uri $pagedUri -Method GET -Headers $using:UIDheaders
                        #$pagedResult = Invoke-WebRequest -Uri $pagedUri -Method GET -Headers $UIDheaders
                        $getComplete = $true
                    }catch{
                        Write-Debug "Error Caught: $_"
                        $retryAttempts++
                        if ($retryAttempts -eq 3){throw "3rd Error on GET: $_"}
                    }
                }
                while(!$getComplete)

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
        $threadSafeDictionary.TryAdd('#NULL#','2000-01-01')
    }
    write-debug "$(get-date -format 'o') Existing uniqueIdentifiers - Data retrieved"

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
        if ($Async)
        {
            $uri += '?async'
        }
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
            #$Body = $Row | Select-Object * -ExcludeProperty $ExcludeProperty

            if ($Row.Table.Columns.Contains("Owner") -and $Row.Owner -ne '') {
                $Body.Owner = $Row.Owner
            } else {
                $Body.PSObject.Properties.Remove("Owner")
            }

            $applications = @()
            if ($null -ne $DPCUserAppDataTable -and $DPCUserAppDataTable.Rows.Count -gt 0)
            {
                foreach($App in $DPCUserAppDataTable.select("userUniqueIdentifier='$($Row.uniqueIdentifier)'"))
                {
                    $applications += @{"applicationDistHierId"=$App.appDistHierId;"applicationBusinessKey"=$App.AppUniqueIdentifier}
                }
            }
            $Body.applications = $applications
            
            $CustomFieldValues = @(
                foreach ($CustomFieldName in $CustomFields) {
                    if ($Row.Table.Columns.Contains($CustomFieldName) -and
                        $Row[$CustomFieldName] -ne [dbnull]::Value)
                    {
                        @{
                            name  = $CustomFieldName
                            value = $Row[$CustomFieldName]
                        }
                    }
                }
            )
            $Body.CustomFieldValues = $CustomFieldValues

            $PropertyEntries = @(
                foreach ($Property in $Properties) {
                    if ($Row.Table.Columns.Contains($Property) -and
                        $Row[$Property] -ne [dbnull]::Value)
                    {
                        @{
                            name  = $Property
                            value = @($Row[$Property])
                        }
                    }
                }
            )
            $Body.Properties = $PropertyEntries

            $BulkUploadObject += $Body

            if ($BulkUploadObject.Count -eq $BatchSize -or $RowCount -eq $dtUserData.Rows.Count)
            {
                $JSONBody = ConvertTo-Json -Depth 10 -InputObject $BulkUploadObject
                $ByteArrayBody = [System.Text.Encoding]::UTF8.GetBytes($JSONBody)
                try{
                    $stopwatch.Start()
                    if ($Async -and $Method -eq 'Post' -and $false) #Not implemented for users yet.
                    {
                        $APIResponse = Invoke-webrequest -Headers $Postheaders -Uri $uri -Method $Method -Body $ByteArrayBody -MaximumRetryCount 3 -RetryIntervalSec 20
                        if ($APIResponse.Headers.Location.Length -gt 0)
                        {
                            $JobDetails = Invoke-RestMethod -Headers @{"X-API-KEY" = "$APIKey"} -Uri $($APIResponse.Headers.Location)
                            while ($JobDetails.status -eq "InProgress")
                            {
                                start-sleep -Milliseconds 500
                                $JobDetails = Invoke-RestMethod -Headers @{"X-API-KEY" = "$APIKey"} -Uri $($APIResponse.Headers.Location)
                            }
                            if ($JobDetails.status -eq "Completed")
                            {
                                foreach($RowResult in $JobDetails.result)
                                {
                                    if($RowResult.status -ne 201)
                                    {
                                        write-debug "$(Get-date -Format 'o'):Job-$($JobDetails.requestId) record-$($RowResult.data.uniqueIdentifier) status-$($RowResult.status):$($RowResult.details)"
                                        #All rows here should be accepted, thus, if there are any failures, end the upload process.
                                        $errorFoundInUpload=$true
                                    }
                                }
                            } elseif ($JobDetails.status -eq "Failed")
                            {
                                write-debug "$(Get-date -Format 'o'):Job-$($JobDetails.requestId) Failed with error-$($JobDetails.error)"
                                $errorFoundInUpload=$true
                            }
                        }else{
                            $errorFoundInUpload=$true
                            throw "$(Get-date -Format 'o'):No job found in response headers"
                        }
                    }else{
                        $APIResponse = Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method $Method -Body $ByteArrayBody -MaximumRetryCount 3 -RetryIntervalSec 20
                        foreach($RowResult in $APIResponse)
                        {
                            if(($Method -eq 'Post' -and $RowResult.status -ne 201) -or ($Method -eq 'Patch' -and $RowResult.status -ne 204))
                            {
                                write-debug "$(Get-date -Format 'o'):Method-$Method Record-$($RowResult.data.uniqueIdentifier) Status-$($RowResult.status) $($RowResult.details)"
                                #All rows here should be accepted, thus, if there are any failures, end the upload process.
                                $errorFoundInUpload=$true
                            }
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
                        #exit 1
                    }
                }
                $BulkUploadObject = @()
            }
        }
    }

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
                $DeleteResponse = Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method $Method -Body $ByteArrayBody -MaximumRetryCount 3 -RetryIntervalSec 20
                $stopwatch.Stop()
                foreach($RowResult in $APIResponse)
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
            }finally{
                if ($errorFoundInUpload)
                {
                    Throw "Errors found in upload. Re-run after enabling debug messages (`$debugPreference = 'Continue')"
                    #exit 1
                }
            }
            $deleteArray = @()
        }
    }
}