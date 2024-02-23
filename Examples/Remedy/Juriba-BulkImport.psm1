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

    .Parameter ImportName
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

        [parameter(Mandatory=$True)]
        [string]$ImportName,

        [parameter(Mandatory=$False)]
        [array]$CustomFields = @(),

        [parameter(Mandatory=$False)]
        [int]$BatchSize = 1000
    )

#Requires -Module @{ModuleName="Juriba.Platform"; ModuleVersion="0.0.52.0"}
# Get Juriba Device Feed
$Devicefeed = Get-JuribaImportDeviceFeed @JuribaParams -Name $ImportName 
Add-LogEntry -Entry "Devicefeed: $Devicefeed"
Add-LogEntry -Entry "ImportName: $ImportName"

# If it doesn't exist, create it
if (-Not $Devicefeed) {
    $Devicefeed = New-JuribaImportDeviceFeed @JuribaParams -Name $ImportName -Enabled $true
    Add-LogEntry -Entry "Device Import Doesn't exists, creating feed." 
}

$DeviceImportID = $Devicefeed.id
Add-LogEntry -Entry "DeviceImportID: $DeviceImportID"  


# Remove previous device feed data
try {Remove-DwImportDeviceFeedAllItem @JuribaParams -ImportId $DeviceImportID -Confirm:$false 

} catch {
    Add-LogEntry -Entry "Error removing device feed: $($_.Exception.Message)"  -JuribaLogLevel Fatal
        }


    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }


    # Log the parameters
Add-LogEntry -Entry "WriteToConsole: $WriteToConsole"  -SendToJuriba $false
Add-LogEntry -Entry "Instance: $Instance"  -SendToJuriba $false
Add-LogEntry -Entry "APIKey: $APIKey"  -SendToJuriba $false
Add-LogEntry -Entry "DeviceImportName: $ImportName" 
Add-LogEntry -Entry "CustomFields: $CustomFields" 
Add-LogEntry -Entry "BatchSize: $BatchSize" 
Add-LogEntry -Entry "Instance: $Instance" 
Add-LogEntry -Entry "deviceImportId: $deviceImportId" 

   # Call the endpoint directly
$uri = '{0}/apiv2/imports/devices/{1}/items/$bulk' -f $Instance, $deviceImportId
Add-LogEntry -Entry "uri: $uri" -SendToJuriba $false
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
            Add-LogEntry -Entry "uri: $uri" -SendToJuriba $false
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

    .Parameter ImportName
    The name of the feed to be searched for and used.

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

        [parameter(Mandatory=$True)]
        [string]$ImportName,

        [parameter(Mandatory=$False)]
        [array]$CustomFields = @(),

        [parameter(Mandatory=$False)]
        [int]$BatchSize = 500
    )

    
    $Postheaders = @{
        "X-API-KEY" = $APIKey
        "Content-Type" = "application/json"
    }
    

    
# Get Juriba User Feed
$Userfeed = Get-JuribaImportUserFeed @JuribaParams -Name $ImportName

# If it doesn't exist, create it
if (-Not $Userfeed) {
    $Userfeed = New-JuribaImportUserFeed @JuribaParams -Name $ImportName -Enabled $true
    Add-LogEntry -Entry "User Import Doesn't exists, creating feed." 
}
$UserImportID = $Userfeed.id
Add-LogEntry -Entry "UserImportID: $UserImportID"  


# remove previous user feed data
try {Remove-JuribaImportUserFeedAllItem @JuribaParams -ImportId $UserImportID -Confirm:$false 
} catch {
    Add-LogEntry -Entry "Error removing user feed: $($_.Exception.Message)"  
       }

# Log the parameters
Add-LogEntry -Entry "WriteToConsole: $WriteToConsole"  -SendToJuriba $false
Add-LogEntry -Entry "Instance: $Instance"  -SendToJuriba $false
Add-LogEntry -Entry "APIKey: $APIKey"  -SendToJuriba $false
Add-LogEntry -Entry "UserImportName: $ImportName" 
Add-LogEntry -Entry "CustomFields: $CustomFields" 
Add-LogEntry -Entry "BatchSize: $BatchSize" 


    # Call the endpoint directly
    $uri = '{0}/apiv2/imports/users/{1}/items/$bulk' -f $Instance, $UserImportId
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
                Add-LogEntry -Entry "uri: $uri" -SendToJuriba $false
            }
            $BulkUploadObject = @()
        }
    }
    # Return a count of processed rows
    Return ("{0} users sent" -f $JuribaUserDataTable.Rows.Count)
}
    