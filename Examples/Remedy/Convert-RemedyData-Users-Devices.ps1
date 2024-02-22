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
    $userTable.Columns.Add("uniqueIdentifier", [string])
    $userTable.Columns.Add("username", [string])
    $userTable.Columns.Add("emailAddress", [string])
    $userTable.Columns.Add("givenName", [string])
    $userTable.Columns.Add("displayName", [string])
    $userTable.Columns.Add("surname", [string])
    $userTable.Columns.Add("disabled", [string])
    $userTable.Columns.Add("RemedyDeskLocation", [string])
    $userTable.Columns.Add("RemedyEmployeeID", [string])
    $userTable.Columns.Add("RemedyJobTitle", [string])
    $userTable.Columns.Add("RemedyManagerEmail", [string])
    $userTable.Columns.Add("RemedyManagersName", [string])
    $userTable.Columns.Add("RemedyPhoneNumberBusiness", [string])


    # Create DataTable for Devices
    $deviceTable = New-Object System.Data.DataTable
    $deviceTable.Columns.Add("uniqueIdentifier", [string])
    $deviceTable.Columns.Add("hostname", [string])
    $deviceTable.Columns.Add("operatingSystemName", [string])
    $deviceTable.Columns.Add("computerManufacturer", [string])
    $deviceTable.Columns.Add("computerModel", [string])
    $deviceTable.Columns.Add("chassisType", [string])
    $deviceTable.Columns.Add("virtualMachine", [string])
    $deviceTable.Columns.Add("lastSeenDate", [System.DateTime])
    $deviceTable.Columns.Add("buildDate", [System.DateTime])
    $deviceTable.Columns.Add("serialNumber", [string])
    $deviceTable.Columns.Add("owner", [string])
    $deviceTable.Columns.Add("RemedySystemEnvironment", [string])
    $deviceTable.Columns.Add("RemedyStatus", [string])

# ====================================================
# Initialize and populate array for customFieldNmes
# ====================================================

$userCustomFieldNames = @("RemedyDeskLocation","RemedyEmployeeID","RemedyJobTitle","RemedyManagerEmail","RemedyManagersName","RemedyPhoneNumberBusiness")
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
        $userRow["RemedyManagerEmail"] = $item."USER_Manager E-mail"}
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
    $deviceRow["owner"] = $item.USER_LANID      # This has now been altered after we used it in user feed to be the full path
    # Dynamically set custom fields if present and not just whitespace
    if (-not [string]::IsNullOrWhiteSpace($item.ASSET_SystemEnvironment)) {
        $userRow["RemedySystemEnvironment"] = $item.ASSET_SystemEnvironment}
    if (-not [string]::IsNullOrWhiteSpace($item.ASSET_LifecycleStatus)) {
        $userRow["RemedyStatus"] = $item.ASSET_LifecycleStatus}
}
   

# =============================================
# Build Bulk Params array
# So we can call the bulk function using splatting
# =============================================

$paramsForUserBulkImport = @{
    Instance           = $JuribaApiEndpoint
    JuribaUserDataTable= $userTable # Assuming $userTable is your prepared DataTable for users
    APIKey             = $JuribaAPIKey
    ImportId           = $UserImportID # Assuming you have fetched or set this ID earlier in your script
    CustomFields       = $userCustomFieldNames # Assuming this array contains the names of your custom fields
    BatchSize          = 1000 # Or whatever batch size you have deemed appropriate
}

$paramsForDeviceBulkImport = @{
    Instance           = $JuribaApiEndpoint
    JuribaUserDataTable= $deviceTable # Assuming $userTable is your prepared DataTable for users
    APIKey             = $JuribaAPIKey
    ImportId           = $deviceImportID # Assuming you have fetched or set this ID earlier in your script
    CustomFields       = $deviceCustomFieldNames # Assuming this array contains the names of your custom fields
    BatchSize          = 1000 # Or whatever batch size you have deemed appropriate
}




# =================================================
#  Now we will call the Function that Bulk Imports
#==================================================

try {
    Invoke-JuribaBulkImportUserFeedDataTable @paramsForUserBulkImport
} catch {
    Add-LogEntry -Entry "Error using Bulk Import User Feed DataTable: $($_.Exception.Message)" -JuribaLogLevel Fatal
    exit
    }

try {
    Invoke-JuribaBulkImportDeviceFeedDataTable @paramsForDeviceBulkImport
} catch {
    Add-LogEntry -Entry "Error using Bulk Import Device Feed DataTable: $($_.Exception.Message)" -JuribaLogLevel Fatal
    exit
    }
    

Close-JuribaLog @JuribaParams



