function Invoke-JuribaBulkImportDeviceFeedDataTable{
    <#
    .Synopsis
    Loops a correctly formatted data table inserting all of the rows it contains.

    .Description
    Takes a System.Data.Datatable object with the columns required for the JuribaAPI device. Inserts these devices one at a time.

    .Parameter Instance
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for and used.

    .Parameter ImportId
    The id of the device feed to be used.

    .Parameter JuribaDataTable
    [System.Data.DataTable] Data table containing the fields required to insert data into the Juriba Device API.

    .Outputs
    Output type [string]
    Text confirming the number of rows to be inserted.

    .Example
    # Get the device feed id for the named feed.
    Write-DeviceFeedData -Instance $Instance -JuribaDataTable $dtDashworksInput -ImportId $DeviceImportID -APIKey $APIKey
    #>

    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,
        [Parameter(Mandatory=$True)]
        [System.Data.DataTable]$JuribaDeviceDataTable,
        [Parameter(Mandatory=$True)]
        [string]$APIKey,
        [parameter(Mandatory=$False)]
        [string]$ImportId,
        [parameter(Mandatory=$False)]
        [array]$CustomFields = @(),
        [parameter(Mandatory=$False)]
        [int]$BatchSize = 1000
    )

# Get Juriba Device Feed
$Devicefeed = Get-JuribaImportDeviceFeed @JuribaParams -Name $DeviceImportName 

# If it doesn't exist, create it
if (-Not $Devicefeed) {
    $Devicefeed = New-JuribaImportDeviceFeed @JuribaParams -Name $DeviceImportName -Enabled $true
    Add-LogEntry -Entry "Device Import Doesn't exists, creating feed." 
}
$DeviceImportID = $Devicefeed.id
Add-LogEntry -Entry "DeviceImportID: $DeviceImportID"  


# Remove previous device feed data
try {Remove-JuribaImportDeviceFeedAllItem @JuribaParams -ImportId $DeviceImportID -Confirm:$false -ErrorVariable apiError

} catch {
    Add-LogEntry -Entry "Error removing device feed: $($_.Exception.Message)"  -JuribaLogLevel Fatal
    if ($apiError) {
        # Log detailed error info
        Add-LogEntry -Entry "API Error: $($apiError | ConvertTo-Json -Depth 10)" 
        }
    return
    }


    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

   # Call the endpoint directly
$uri = '{0}/apiv2/imports/devices/{1}/items/$bulk' -f $Instance, $ImportId
$ExcludeProperty = @("ItemArray", "Table", "RowError", "RowState", "HasErrors")
if ($CustomFields.count -gt 0) {
    $ExcludeProperty += $CustomFields
}

$BulkUploadObject = @()
$RowCount = 0
foreach ($Row in $JuribaDeviceDataTable.Rows) {
    $RowCount++
    $Body = $null
    $Body = $Row | Select-Object *, CustomFieldValues -ExcludeProperty $ExcludeProperty
    
    $CustomFieldValues = @()
    $CFVtemplate = 'if ($Row.### -ne [dbnull]::value) {
                        $CustomField = @{
                            name = "###"
                            value = $Row.###
                        }
                        $CustomField
                    }'
    
    foreach ($CustomFieldName in $CustomFields) {
        $ScriptBlock = $null
        $ScriptBlock = $CFVtemplate.Replace('###', $CustomFieldName)
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)
        $CustomFieldValues += & $ScriptBlock
    }
    $Body.CustomFieldValues = $CustomFieldValues
    
    $BulkUploadObject += $Body
    
    if ($BulkUploadObject.Count -eq $BatchSize -or $RowCount -eq $JuribaDeviceDataTable.Rows.Count) {
        $JSONBody = $BulkUploadObject | ConvertTo-Json -Depth 10
        $ByteArrayBody = [System.Text.Encoding]::UTF8.GetBytes($JSONBody)
        try {
            Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $ByteArrayBody -MaximumRetryCount 3 -RetryIntervalSec 20
            Add-LogEntry -Entry "$(Get-date -Format 'o'): $RowCount rows processed" -JuribaLogLevel "Debug"
        } catch {
            $timeNow = (Get-date -Format 'o')
            Add-LogEntry -Entry "$timeNow; Error during bulk upload: $($_.Exception.Message)" -JuribaLogLevel "Error"
        }
        $BulkUploadObject = @()
    }
}
Return ("{0} devices sent" -f $RowCount)

}

function Invoke-JuribaBulkImportUserFeedDataTable{
    <#
    .Synopsis
    Loops a correctly formatted data table inserting all of the rows it contains.

    .Description
    Takes a System.Data.Datatable object with the columns required for the Juriba API user. Inserts these users one at a time.

    .Parameter Instance
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter ImportId
    The id of the user feed to be used.

    .Parameter JuribaDataTable
    [System.Data.DataTable] Data table containing the fields required to insert data into the Juriba user API.

    .Outputs
    Output type [string]
    Text confirming the number of rows to be inserted.

    .Example
    # Get the user feed id for the named feed.
    Write-UserFeedData -Instance $Instance -JuribaDataTable $dtDashworksInput -ImportId $userImportID -APIKey $APIKey
    #>

    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,

        [Parameter(Mandatory=$True)]
        [System.Data.DataTable]$JuribaUserDataTable,

        [Parameter(Mandatory=$True)]
        [string]$APIKey,

        [parameter(Mandatory=$False)]
        [string]$FeedName = $null,

        [parameter(Mandatory=$False)]
        [string]$ImportId,

        [parameter(Mandatory=$False)]
        [array]$CustomFields = @(),

        [parameter(Mandatory=$False)]
        [int]$BatchSize = 500
    )


# Get Juriba User Feed
$Userfeed = Get-JuribaImportUserFeed @JuribaParams -Name $UserImportName

# If it doesn't exist, create it
if (-Not $Userfeed) {
    $Userfeed = New-JuribaImportUserFeed @JuribaParams -Name $UsersviceImportName -Enabled $true
    Add-LogEntry -Entry "User Import Doesn't exists, creating feed." 
}
$UserImportID = $Userfeed.id
Add-LogEntry -Entry "UserImportID: $UserImportID"  


# remove previous user feed data
try {Remove-JuribaImportUserFeedAllItem @JuribaParams -ImportId $UserImportID -Confirm:$false -ErrorVariable apiError 
} catch {
    Add-LogEntry -Entry "Error removing user feed: $($_.Exception.Message)"  -JuribaLogLevel Fatal
    if ($apiError) {
        # Log detailed error info
        Add-LogEntry -Entry "API Error: $($apiError | ConvertTo-Json -Depth 10)" 
        }
    exit
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }
    
    # Call the endpoint directly
    $uri = '{0}/apiv2/imports/users/{1}/items/$bulk' -f $Instance, $ImportId
    $ExcludeProperty = @("ItemArray", "Table", "RowError", "RowState", "HasErrors")
    if ($CustomFields.count -gt 0) {$ExcludeProperty += $CustomFields}
    
    $BulkUploadObject = @()
    $RowCount = 0
    foreach ($Row in $JuribaUserDataTable.Rows) {
        $RowCount++
        $Body = $null
        $Body = $Row | Select-Object *, CustomFieldValues -ExcludeProperty $ExcludeProperty
        
        $CustomFieldValues = @()
        $CFVtemplate = 'if ($Row.### -ne [dbnull]::value) {
                            $CustomField = @{
                                name = "###"
                                value = $Row.###
                            }
                            $CustomField
                        }'
    
        foreach ($CustomFieldName in $CustomFields) {
            $ScriptBlock = $null
            $ScriptBlock = $CFVtemplate.Replace('###', $CustomFieldName)
            $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)
            $CustomFieldValues += & $ScriptBlock
        }
        $Body.CustomFieldValues = $CustomFieldValues
    
        $BulkUploadObject += $Body
    
        if ($BulkUploadObject.Count -eq $BatchSize -or $RowCount -eq $JuribaUserDataTable.Rows.Count) {
            $JSONBody = $BulkUploadObject | ConvertTo-Json -Depth 10
            $ByteArrayBody = [System.Text.Encoding]::UTF8.GetBytes($JSONBody)
            try {
                Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $ByteArrayBody -MaximumRetryCount 3 -RetryIntervalSec 20
                Add-LogEntry -Entry "$(Get-date -Format 'o'): $RowCount rows processed" -JuribaLogLevel "Debug"
            } catch {
                $timeNow = (Get-date -Format 'o')
                Add-LogEntry -Entry "$timeNow; Error during bulk upload: $($_.Exception.Message)" -JuribaLogLevel "Error"
            }
            $BulkUploadObject = @()
        }
    }
    # Assuming you are returning a count of processed rows or similar
    Return ("{0} users sent" -f $JuribaUserDataTable.Rows.Count)
}
    