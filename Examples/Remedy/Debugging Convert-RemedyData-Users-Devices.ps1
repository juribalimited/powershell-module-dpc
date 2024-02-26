function Invoke-DwBulkImportUserFeedDataTable{
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
        [System.Data.DataTable]$DWUserDataTable,

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


    if (-not $ImportId)
    {
        if (-not $FeedName)
        {
            return 'User feed not found by name or ID'
        }

        $ImportId = (Get-JuribaImportUserFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName).id
        Add-LogEntry -Entry "Instance: $Instance" -SendToJuriba $false
        Add-LogEntry -Entry "APIKey: $APIKey" -SendToJuriba $false
        Add-LogEntry -Entry "FeedName: $FeedName" -SendToJuriba $false
        Add-LogEntry -Entry "ImportId: $ImportId" -SendToJuriba $false

        if (-not $ImportId)
        {
            Add-LogEntry -Entry 'User feed not found by name or ID'
        } else {
            
            $Deleteheaders = @{
                                "X-API-KEY" = "$APIKey"
                            }
            $Deleteuri = "{0}/apiv2/imports/users/{1}/items" -f $Instance, $ImportId
            Invoke-RestMethod -Headers $Deleteheaders -Uri $Deleteuri -Method Delete
            Add-LogEntry -Entry "Deleteheaders: $Deleteheaders" -SendToJuriba $false
            Add-LogEntry -Entry "Deleteuri: $Deleteuri" -SendToJuriba $false
            Add-LogEntry -Entry "Deleted records for ImportID $ImportID, $Feedname" -SendToJuriba $false
        }
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = '{0}/apiv2/imports/users/{1}/items/$bulk' -f $Instance, $ImportId
    $ExcludeProperty = @("ItemArray", "Table", "RowError", "RowState", "HasErrors")
    if ($CustomFields.count -gt 0) {$ExcludeProperty += $CustomFields}

    $BulkUploadObject = @()
    $RowCount = 0
    foreach($Row in $DWUserDataTable.Rows){
        $RowCount++
        $Body = $null
        $Body = $Row | Select-Object *,CustomFieldValues -ExcludeProperty $ExcludeProperty
        
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
            $CustomFieldValues += & $ScriptBlock
        }
        $Body.CustomFieldValues = $CustomFieldValues

        $BulkUploadObject += $Body
        Add-LogEntry -Entry "BulkUploadObject: $BulkUploadObject" -SendToJuriba $false
        Add-LogEntry -Entry "BulkUploadObject Count: $BulkUploadObject.Count"

        if ($BulkUploadObject.Count -eq $BatchSize -or $RowCount -eq $DWUserDataTable.Rows.Count)
        {
            $JSONBody = $BulkUploadObject | ConvertTo-Json -Depth 10
            $ByteArrayBody = [System.Text.Encoding]::UTF8.GetBytes($JSONBody)
            Add-LogEntry "$(Get-date -Format 'o'):$RowCount rows processed"
            Add-LogEntry "ByteArrayBody: $ByteArrayBody" -SendToJuriba $false
            Add-LogEntry "uri :$uri" -SendToJuriba $false
            Add-LogEntry "Postheaders: $Postheaders" -SendToJuriba $false

            try{
                $dummy = Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $ByteArrayBody -MaximumRetryCount 3 -RetryIntervalSec 20
            }catch{
                $timeNow = (Get-date -Format 'o')
                write-error "$timeNow;$_"
            }
            $BulkUploadObject = @()
        }
    }
    Return $threadSafeDictionary
}
<#
.Synopsis
Reads JSON Data to process and bulk inserts into Juriba. Specifically designed for large datasets of Remedy users and devices.

.Description
This script is designed to efficiently process and import Remedy data into a Juriba instance using bulk import techniques for enhanced performance. It handles the mapping, validation, and import of users and devices data, ensuring data integrity and minimizing processing time.

.Parameter jsonFilePath
Specifies the file path of the JSON file containing Remedy data to be imported.

.Parameter JuribaApiEndpoint
Defines the URI of the Juriba instance where the data will be imported.

.Parameter JuribaAPIKey
Provides the API key for accessing the required resources in the Juriba instance.

.Parameter UserImportName
Indicates the name of the Juriba feed set up for importing Remedy Users.

.Parameter DeviceImportName
Indicates the name of the Juriba feed set up for importing Remedy Devices.

.Parameter WriteToConsole
A boolean flag indicating whether to write log entries to the console for immediate feedback during script execution. Useful for debugging and monitoring script progress.

.Example
.\ImportRemedyDataToJuriba.ps1 -jsonFilePath "C:\Data\remedy_data.json" -JuribaApiEndpoint "https://juriba.example.com" -JuribaAPIKey "your_api_key_here" -UserImportName "Remedy Users" -DeviceImportName "Remedy Devices" -WriteToConsole $true

.Notes
Ensure that the Juriba instance API endpoint, API key, and feed names are correctly specified to avoid import failures. 
The script includes error handling to log and exit gracefully in case of encountered errors during the import process.

#>
<#
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$jsonFilePath,
    
    [Parameter(Mandatory=$true)]
    [string]$JuribaApiEndpoint,
    
    [Parameter(Mandatory=$true)]
    [string]$JuribaAPIKey,
    
    [Parameter(Mandatory=$true)]
    [string]$UserImportName,
    
    [Parameter(Mandatory=$true)]
    [string]$DeviceImportName,
      
    [Parameter(Mandatory=$true)]
    [bool]$WriteToConsole = $true
)
#>
$JuribaApiEndpoint= "https://dw-noel-demo.dwlabs.local:8443" 
$JuribaAPIKey= "oo3qcwyR7em7c4Z6aIRDpH4WzkO/Ua4pbU0suz66mBzZZinE+AgkL3OTHAvXqHRm5YtNBOz9BnCFxBd/5EaZLw==" 
$DeviceImportName= "Remedy Devices" 
$UserImportName= "Remedy Users"
$jsonFilePath= "F:\Projects\Remedy\SampleData\remedy_data.json" 
$WriteToConsole= $true # Switch logging so it also creates a console entry for faster debugging
Import-Module -Name Juriba.Platform -RequiredVersion 0.0.54.0

# Define $JuribaParams globally
$global:JuribaParams = @{
    Instance = $JuribaApiEndpoint
    APIKey = $JuribaAPIKey
}


#Requires -Module @{ModuleName="Juriba.Platform"; ModuleVersion="0.0.52.0"}

# Build the path to the logging module
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath "Juriba-Logging.psm1"

# Import the logging module
if (Test-Path -Path $modulePath) {
    Import-Module -Name $modulePath
} else {
    Add-LogEntry -Entry "Module file not found at path: $modulePath" 
}

# Build the path to the Juriba-BulkImport module
$bulkImportModulePath = Join-Path -Path $PSScriptRoot -ChildPath "Juriba-BulkImport.psm1"

# Import the Juriba-BulkImport module
if (Test-Path -Path $bulkImportModulePath) {
    Import-Module -Name $bulkImportModulePath
} else {
    # Log an error if the module file is not found
    # Assuming Add-LogEntry function is available from the previously loaded Juriba-Logging module
    Add-LogEntry -Entry "Juriba-BulkImport module file not found at path: $bulkImportModulePath" -JuribaLogLevel "Error"
}


Start-JuribaLog @JuribaParams

# Log the parameters
Add-LogEntry -Entry "WriteToConsole: $WriteToConsole"  -SendToJuriba $false
Add-LogEntry -Entry "jsonFilePath: $jsonFilePath"  -SendToJuriba $false
Add-LogEntry -Entry "JuribaApiEndpoint: $JuribaApiEndpoint"  -SendToJuriba $false
Add-LogEntry -Entry "JuribaAPIKey: $JuribaAPIKey"  -SendToJuriba $false
Add-LogEntry -Entry "UserImportName: $UserImportName" 
Add-LogEntry -Entry "DeviceImportName: $DeviceImportName" 


# =====================
#  Read the JSON  
# =====================

# Retrieve the data from the Remedy JSON file path
$remedyData = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json
Add-LogEntry -Entry "Processing remedy data with count: $($remedyData.Count)" 


# =============================
#  Read & Map the Remedy Data
# ==============================

$devicesWithoutOwner = 0  # Initialize a variable to count devices without owners

# =====================================================================================
#   Creat the System.Data.DataTables that will be used to send data to a Bulk Function
# =====================================================================================

    # Create DataTable for Users
$userTable = New-Object System.Data.DataTable
[void]$userTable.Columns.Add("uniqueIdentifier", [string])
[void]$userTable.Columns.Add("username", [string])
[void]$userTable.Columns.Add("emailAddress", [string])
[void]$userTable.Columns.Add("givenName", [string])
[void]$userTable.Columns.Add("displayName", [string])
[void]$userTable.Columns.Add("surname", [string])
[void]$userTable.Columns.Add("disabled", [string])
[void]$userTable.Columns.Add("RemedyDeskLocation", [string])
[void]$userTable.Columns.Add("RemedyEmployeeID", [string])
[void]$userTable.Columns.Add("RemedyJobTitle", [string])
[void]$userTable.Columns.Add("RemedyManagersEmail", [string])
[void]$userTable.Columns.Add("RemedyManagersName", [string])
[void]$userTable.Columns.Add("RemedyPhoneNumberBusiness", [string])

# Create DataTable for Devices
$deviceTable = New-Object System.Data.DataTable
[void]$deviceTable.Columns.Add("uniqueIdentifier", [string])
[void]$deviceTable.Columns.Add("hostname", [string])
[void]$deviceTable.Columns.Add("operatingSystemName", [string])
[void]$deviceTable.Columns.Add("computerManufacturer", [string])
[void]$deviceTable.Columns.Add("computerModel", [string])
[void]$deviceTable.Columns.Add("chassisType", [string])
[void]$deviceTable.Columns.Add("virtualMachine", [string])
[void]$deviceTable.Columns.Add("lastSeenDate", [System.DateTime])
[void]$deviceTable.Columns.Add("buildDate", [System.DateTime])
[void]$deviceTable.Columns.Add("serialNumber", [string])
[void]$deviceTable.Columns.Add("owner", [string])
[void]$deviceTable.Columns.Add("RemedySystemEnvironment", [string])
[void]$deviceTable.Columns.Add("RemedyStatus", [string])


# ====================================================
# Initialize and populate array for customFieldNmes
# ====================================================

$userCustomFieldNames = @("RemedyDeskLocation","RemedyEmployeeID","RemedyJobTitle","RemedyManagersEmail","RemedyManagersName","RemedyPhoneNumberBusiness")
$deviceCustomFieldNames = @("RemedySystemEnvironment","RemedyStatus")


# ================================
# Now Iterate thru Remedy Data
# =============================

# Initialize a hashtable to keep track of processed users
$processedUsers = @{}

foreach ($item in $remedyData) {
    Add-LogEntry -Entry "Processing item: $($item.ASSET_Name)" -SendToJuriba $false

    # Map the user data first.  Map the data and dynamically add custom fields if they are not null/empty
    $userID = $item.USER_LANID
    # Check if the user has already been processed
    if ($processedUsers.ContainsKey($userID)) {
        # Skip processing this item since the user already exists
        Add-LogEntry -Entry "User with ID $userID already processed, skipping..." -SendToJuriba $false
        continue
    } else {
    # Mark the user as processed
        $processedUsers[$userID] = $true
        $userRow = $userTable.NewRow()
        $userRow["uniqueIdentifier"] = $item.USER_LANID
        $userRow["username"] = $item.USER_LANID
        $userRow["emailAddress"] = $item."USER_Corporate E-Mail"
        $userRow["givenName"] = $item."USER_First Name"
        $userRow["displayName"] = $item."USER_Full Name"
        $userRow["surname"] = $item."USER_Last Name"
        $userRow["disabled"] = ($item.USER_Status -eq "Disabled") 
        # Dynamically set custom fields if present and not just whitespace
    if (-not [string]::IsNullOrWhiteSpace($item."USER_Desk Location")) {
        $userRow["RemedyDeskLocation"] = $item."USER_Desk Location"}
    if (-not [string]::IsNullOrWhiteSpace($item."USER_EmployeeID")) {
        $userRow["RemedyEmployeeID"] = $item."USER_EmployeeID"}
    if (-not [string]::IsNullOrWhiteSpace($item."USER_JobTitle")) {
        $userRow["RemedyJobTitle"] = $item."USER_JobTitle"}
    if (-not [string]::IsNullOrWhiteSpace($item."USER_Manager E-mail")) {
        $userRow["RemedyManagersEmail"] = $item."USER_Manager E-mail"}
    if (-not [string]::IsNullOrWhiteSpace($item."USER_ManagersName")) {
        $userRow["RemedyManagersName"] = $item."USER_ManagersName"}
    if (-not [string]::IsNullOrWhiteSpace($item."USER_Phone Number Business")) {
        $userRow["RemedyPhoneNumberBusiness"] = $item."USER_Phone Number Business"}

        # After processing, add the DataRow to the DataTable
        $userTable.Rows.Add($userRow)
    }

# Now Map the Device data  Map the data and dynamically add custom fields if they are not null/empty
    # Validate and possibly truncate the ComputerModel field
    if ($item.ASSET_Model.Length -gt 50) {
        Add-LogEntry -Entry "Warning: Truncating ComputerModel for $($item.ASSET_Name) as it exceeds 50 characters."
        $item.ASSET_Model = $item.ASSET_Model.Substring(0, 50)
    }
    
    # Check if $item.USER_LANID is null or empty 
    if (-not [string]::IsNullOrWhiteSpace($item.USER_LANID)) {
    # Append "/imports/users/5/items/" to the existing column value which will be mapped to owner
    $item.USER_LANID = "/imports/users/$UserimportId/items/" + $item.USER_LANID
     } else {    # Increment the count of devices without owners
                  $devicesWithoutOwner++ }

# Map the device data

# Check if serial number is null or empty
if ([string]::IsNullOrWhiteSpace($item.ASSET_SerialNumber)) {
    # Log an error for the missing serial number
    Add-LogEntry -Entry "Skipping device due to missing serial number: $($item.ASSET_Name)" -SendToJuriba $true
    
    # Skip the rest of this iteration, moving to the next item
    continue
}
 # Proceed with setting DataRow values since serial number is present
    $deviceRow = $deviceTable.NewRow()
    $deviceRow["uniqueIdentifier"] = $item.USER_LANID
    $deviceRow["hostname"] = $item.ASSET_Name
    $deviceRow["operatingSystemName"] = $item.ASSET_OperatingSystem
    $deviceRow["computerManufacturer"] = $item.ASSET_Manufacturer
    $deviceRow["computerModel"] = $item.ASSET_Model
    $deviceRow["chassisType"] = $item.ASSET_Item
    $deviceRow["virtualMachine"] = $item.ASSET_IsVirtual
    $deviceRow["lastSeenDate"] = $item.ASSET_LastScanDate
    $deviceRow["buildDate"] = $item.ASSET_InstallationDate
    $deviceRow["serialNumber"] = $item.ASSET_SerialNumber
    $deviceRow["owner"] = $item.USER_LANID      
    # Dynamically set custom fields if present and not just whitespace
    if (-not [string]::IsNullOrWhiteSpace($item.ASSET_SystemEnvironment)) {
        $deviceRow["RemedySystemEnvironment"] = $item.ASSET_SystemEnvironment}
    if (-not [string]::IsNullOrWhiteSpace($item.ASSET_Status)) {
        $deviceRow["RemedyStatus"] = $item.ASSET_Status}
}
   

# =============================================
# Build Bulk Params array
# So we can call the bulk function using splatting
# =============================================

$paramsForUserBulkImport = @{
    Instance           = $JuribaApiEndpoint
    JuribaUserDataTable= $userTable 
    APIKey             = $JuribaAPIKey
    ImportName         = $UserImportName 
    CustomFields       = $userCustomFieldNames 
    BatchSize          = 7 # Or whatever batch size you have deemed appropriate
}

$paramsForDeviceBulkImport = @{
    Instance           = $JuribaApiEndpoint
    JuribaDeviceDataTable= $deviceTable 
    APIKey             = $JuribaAPIKey
    ImportName         = $deviceImportName 
    CustomFields       = $deviceCustomFieldNames 
    BatchSize          = 7 # Or whatever batch size you have deemed appropriate
}
# =================================================
#  Now we will call the Function that Bulk Imports
#==================================================
<#
try {
    Invoke-JuribaBulkImportUserFeedDataTable @paramsForUserBulkImport
} catch {
    Add-LogEntry -Entry "Error using Bulk Import User Feed DataTable: $($_.Exception.Message)" -JuribaLogLevel Fatal
    exit
    }
#>
try {
    Invoke-DwBulkImportUserFeedDataTable -APIKey $JuribaAPIKey -Instance $JuribaApiEndpoint -FeedName $UserImportName -CustomFields $userCustomFieldNames -DWUserDataTable $userTable -BatchSize 7
} catch {
    Add-LogEntry -Entry "Error using Bulk Import Device Feed DataTable: $($_.Exception.Message)" -JuribaLogLevel Fatal
   }

   <#
    # Convert selected parameters to JSON for logging
    $selectedParamsJson = $selectedParamsForLogging | ConvertTo-Json
    Add-LogEntry -Entry "Selected Parameters for Device Bulk Import: `n$selectedParamsJson" -SendToJuriba $false
    #>
    Close-JuribaLog @JuribaParams






