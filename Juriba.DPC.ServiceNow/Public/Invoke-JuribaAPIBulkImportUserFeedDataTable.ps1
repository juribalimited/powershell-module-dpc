function Invoke-JuribaAPIBulkImportUserFeedDataTable{
    <#
    .Synopsis
    Loops a correctly formatted data table inserting all of the rows it contains.

    .Description
    Takes a System.Data.Datatable object with the columns required for the DwAPI user. Inserts these users one at a time.

    .Parameter Instance
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for and used.

    .Parameter ImportId
    The id of the user feed to be used.

    .Parameter DWDataTable
    [System.Data.DataTable] Data table containing the fields required to insert data into the DW user API.

    .Parameter DPCUserAppDataTable
    [System.Data.DataTable] Data table containing the columns userUniqueIdentifier, appUniqueIdentifier & appDistHierId
    
    .Outputs
    Output type [string]
    Text confirming the number of rows to be inserted.

    .Example
    # Get the user feed id for the named feed.
    Write-UserFeedData -Instance $Instance -DWDataTable $dtDashworksInput -ImportId $userImportID -APIKey $APIKey
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

    $Deleteheaders = @{"X-API-KEY" = "$APIKey"}

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
            write-error "User feed lookup returned no results"
            exit 1
        }

        if (-not $ImportId)
        {
            return 'User feed not found by name or ID'
        } else {
            $Deleteuri = "{0}/apiv2/imports/users/{1}/items" -f $Instance, $ImportId
            Invoke-RestMethod -Headers $Deleteheaders -Uri $Deleteuri -Method Delete | out-null
            Write-Debug ("$(get-date -format 'o'):INFO: Deleted records for ImportID $ImportID, $Feedname")
        }
    }

    #wait until all of the objects are deleted from the feed.
    try{
        while(((Invoke-RestMethod -uri "$Instance/apiv1/admin/data-imports" -Method Get -Headers $Deleteheaders) | Where-Object{$_.typeName -eq 'directory' -and $_.id -eq $ImportID}).ObjectsCount -gt 0)
        {
            Start-sleep 2
            write-debug "$(get-date -format 'o'):Waiting for delete to complete"
        }
    } catch {
        write-error "Reading of data imports failed, check the APIv1 is accessible to external tools"
        exit 1
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = '{0}/apiv2/imports/users/{1}/items/$bulk' -f $Instance, $ImportId
    $ExcludeProperty = @("ItemArray", "Table", "RowError", "RowState", "HasErrors")
    if ($CustomFields.count -gt 0) {$ExcludeProperty += $CustomFields}
    if ($Properties.count -gt 0) {$ExcludeProperty += $Properties}

    $BulkUploadObject = @()
    $RowCount = 0
    foreach($Row in $DPCUserDataTable.Rows){
        $RowCount++
        $Body = $null
        $Body = $Row | Select-Object *,CustomFieldValues,Properties,applications -ExcludeProperty $ExcludeProperty

        $applications = @()
        if ($null -ne $DPCUserAppDataTable -and $DPCUserAppDataTable.Rows.Count -gt 0)
        {
            foreach($App in $DPCUserAppDataTable.select("userUniqueIdentifier='$($Row.uniqueIdentifier)'"))
            {
                $applications += @{"applicationDistHierId"=$App.appDistHierId;"applicationBusinessKey"=$App.AppUniqueIdentifier}
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

        if ($BulkUploadObject.Count -eq $BatchSize -or $RowCount -eq $DPCUserDataTable.Rows.Count)
        {
            $JSONBody = $BulkUploadObject | ConvertTo-Json -Depth 10
            $ByteArrayBody = [System.Text.Encoding]::UTF8.GetBytes($JSONBody)
            try{
                Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $ByteArrayBody -MaximumRetryCount 3 -RetryIntervalSec 20 | Out-Null
                write-debug "$(Get-date -Format 'o'):$RowCount rows processed"
            }catch{
                $timeNow = (Get-date -Format 'o')
                write-error "$timeNow;$_"
            }
            $BulkUploadObject = @()
        }
    }
}