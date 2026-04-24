<#
.SYNOPSIS
Imports Intune-managed device metadata into Juriba DPC.

.DESCRIPTION
This script authenticates to Microsoft Entra ID using application credentials,
retrieves managed device data from Microsoft Intune via Microsoft Graph,
transforms the data into a Juriba DPC-compatible format, and uploads it to Juriba
using the DPC bulk import API.

.PARAMETER TenantId
The Microsoft Entra ID tenant ID used to acquire a Microsoft Graph access token.

.PARAMETER ClientId
The application (client) ID registered in Microsoft Entra ID.

.PARAMETER ClientSecret
The client secret associated with the Entra ID application registration.

.PARAMETER GraphUsersUri
Optional Microsoft Graph endpoint URI for users.

Defaults to:
`https://graph.microsoft.com/beta/users`

This parameter is primarily intended for pagination or advanced scenarios.

.PARAMETER GraphDevicesUri
Optional Microsoft Graph endpoint URI for devices.

Defaults to:
`https://graph.microsoft.com/beta/deviceManagement/managedDevices`

This parameter is primarily intended for pagination or advanced scenarios.

.PARAMETER Instance
The Juriba DPC instance.

.PARAMETER ApiKey
The API key to connect to the Juriba DPC instance.

.PARAMETER EntraIdIntuneImportId
The Juriba DPC universal data import ID.

.PARAMETER ParametersFilepath
Optional file path to a PowerShell parameters file containing environment-
specific values (for example, instance name or API key).

When specified, values for TenantId, ClientId, ClientSecret, Instance and ApiKey 
will be loaded from the parameters file and will override any values supplied on the command line.

.PARAMETER JuribaLoggingModuleFilepath
Optional file path to the Juriba logging PowerShell module.

.PARAMETER DeviceProperties
An array of device properties to include when transforming Intune
device data for Juriba DPC. Defaults to a standard set of commonly useful
metadata fields.

.PARAMETER IncludeApps
A switch which controls whether to include application data that a device is assigned to.

.PARAMETER IncludeNonComplianceData
A switch which controls whether to include details of non-compliant devices. It will return
a count of non-compliant policies and the those policies. These fields will be stored as properties
of the device in Juriba DPC.

.OUTPUTS
None. Data is imported directly into Juriba DPC.

.EXAMPLE
.\Juriba_Import_Intune_Devices.ps1 `
    -TenantId "00000000-0000-0000-0000-000000000000" `
    -ClientId "11111111-1111-1111-1111-111111111111" `
    -ClientSecret "client-secret-value"

.EXAMPLE
.\Juriba_Import_Intune_Devices.ps1 `
    -TenantId "00000000-0000-0000-0000-000000000000" `
    -ClientId "11111111-1111-1111-1111-111111111111" `
    -ClientSecret "client-secret-value" `
    -AppProperties @("complianceState","lastSyncDateTime","managementState")

.NOTES
Requires:
- Juriba.DPC.Graph PowerShell module
- Juriba.DPC.Functions PowerShell module
- Juriba.DPC PowerShell module
- Juriba logging module

Microsoft Graph permissions must allow access to Intune application metadata.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientId,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$GraphUsersUri = "https://graph.microsoft.com/beta/users",

    
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$GraphDevicesUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Instance,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApiKey,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$EntraIdIntuneImportId,

    [Parameter(Mandatory = $false)]
    [string]$ParametersFilepath, 

    [Parameter(Mandatory = $false)]
    [string]$JuribaLoggingModuleFilepath,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$DeviceProperties = @(
        "autopilotEnrolled",
        "azureADRegistered",
        "complianceGracePeriodExpirationDateTime",
        "complianceState",
        "deviceEnrollmentType",
        "easActivated",
        "enrolledDateTime",
        "lastSyncDateTime",
        "managementCertificateExpirationDate",
        "managedDeviceOwnerType",
        "managementState",
        "ownerType"
    ),

    [Parameter(Mandatory = $false)]
    [switch]$IncludeApps,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeNonComplianceData
)

# Set the script location
Set-Location $PSScriptRoot

# Import Juriba logging module (optional override)
$defaultLoggingModule = Join-Path $PSScriptRoot 'Juriba-Logging.psm1'

if ($PSBoundParameters.ContainsKey('JuribaLoggingModuleFilepath')) {
    if (Test-Path $JuribaLoggingModuleFilepath) {
        Add-LogEntry -Entry "Importing Juriba logging module from $JuribaLoggingModuleFilepath" -LogLevel Info
        Import-Module $JuribaLoggingModuleFilepath -Force
    }
    else {
        Add-LogEntry -Entry "JuribaLoggingModuleFilepath was provided but does not exist: $JuribaLoggingModuleFilepath" -LogLevel Error
        throw "Invalid JuribaLoggingModuleFilepath"
    }
}
elseif (Test-Path $defaultLoggingModule) {
    Add-LogEntry -Entry "Importing default Juriba logging module from $defaultLoggingModule" -LogLevel Info
    Import-Module $defaultLoggingModule -Force
}
else {
    Add-LogEntry -Entry "Juriba logging module could not be found and no filepath was supplied" -LogLevel Error
    throw "Juriba logging module not available"
}

# Import parameters file (optional override)
$defaultParametersFile = Join-Path $PSScriptRoot 'Parameters.ps1'

if ($PSBoundParameters.ContainsKey('ParametersFilepath')) {
    if (Test-Path $ParametersFilepath) {
        Add-LogEntry -Entry "Importing parameters from $ParametersFilepath" -LogLevel Info
        . $ParametersFilepath
    }
    else {
        Add-LogEntry -Entry "ParametersFilepath was provided but does not exist: $ParametersFilepath" -LogLevel Error
        throw "Invalid ParametersFilepath"
    }
}
elseif (Test-Path $defaultParametersFile) {
    Add-LogEntry -Entry "Importing default parameters file from $defaultParametersFile" -LogLevel Info
    . $defaultParametersFile
}
else {
    Add-LogEntry -Entry "No parameters file supplied and no default Parameters.ps1 found" -LogLevel Info
}

# Validate required configuration values (CLI or parameters file)
$requiredValues = @(
    'TenantId',
    'ClientId',
    'ClientSecret',
    'Instance',
    'ApiKey',
    'EntraIdIntuneImportId'
)

$missingValues = @()

foreach ($value in $requiredValues) {
    if (-not (Get-Variable -Name $value -Scope Script -ErrorAction SilentlyContinue) -or
        [string]::IsNullOrWhiteSpace((Get-Variable -Name $value -Scope Script).Value)) {
        $missingValues += $value
    }
}

if ($missingValues.Count -gt 0) {
    Add-LogEntry `
        -Entry "Missing required configuration values: $($missingValues -join ', '). Provide them via CLI parameters or a parameters file." `
        -LogLevel Error

    throw "Required configuration values missing"
}

Add-LogEntry -Entry "All required configuration values successfully resolved" -LogLevel Info

# Import Juriba Intune module
Import-Module .\Juriba.DPC.Graph\Juriba.DPC.Graph.psm1

# Import Juriba functions module
Import-Module .\Juriba.DPC.Functions\Juriba.DPC.Functions.psm1

# Import Juriba DPC module
Import-Module Juriba.DPC

# Connect to Juriba
Connect-Juriba -Instance $Instance -APIKey $ApiKey

# Get an access token
try {
    Add-LogEntry -Entry "Getting access token" -LogLevel Info
    $token = Get-GraphOAuthToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
    $accessToken = $token.access_token
}
catch {
    Add-LogEntry -Entry "Unable to retrieve access token" -LogLevel Error
    Add-LogEntry -Entry "$_" -LogLevel Debug
}

if ($accessToken) {
    $tokenIssueTime = Get-Date
    $tokenExpiry = $tokenIssueTime.AddSeconds($token.expires_in)
    $refreshBuffer = 300
    $tokenRefreshTime = $tokenExpiry.AddSeconds(-$refreshBuffer)

    Add-LogEntry -Entry "Successfully retrieved access token. Token expiry = $tokenExpiry. Token refresh time = $tokenRefreshTime"
}

# Get users
try {
    Add-LogEntry -Entry "Getting users from Entra ID" -LogLevel Info
    $users = Get-EntraIdUser `
        -AccessToken $accessToken `
        -Uri $GraphUsersUri
}
catch {
    Add-LogEntry -Entry "Unable to retrieve users" -LogLevel Error
    Add-LogEntry -Entry "$_" -LogLevel Debug
}

# Convert users to Juriba DPC
try {
    Add-LogEntry -Entry "Converting users to Juriba DPC format" -LogLevel Info
    $juribaUsers = Convert-EntraIdUsersToJuribaDPC `
    -Rows $users `
}
catch {
    Add-LogEntry -Entry "Unable to convert users to Juriba DPC format" -LogLevel Error
    Add-LogEntry -Entry "$_" -LogLevel Debug
}

# Get devices
try {
    Add-LogEntry -Entry "Getting devices from Intune" -LogLevel Info
    $devices = Get-IntuneDevice `
        -AccessToken $accessToken `
        -Uri $GraphDevicesUri
}
catch {
    Add-LogEntry -Entry "Unable to retrieve devices" -LogLevel Error
    Add-LogEntry -Entry "$_" -LogLevel Debug
}

# Convert devices to Juriba DPC
try {
    Add-LogEntry -Entry "Converting devices to Juriba DPC format" -LogLevel Info
    $juribaDevices = Convert-IntuneDevicesToJuribaDPC `
    -Rows $devices `
    -IncludeProperties $DeviceProperties `
    -ImportId $EntraIdIntuneImportId
}
catch {
    Add-LogEntry -Entry "Unable to convert devices to Juriba DPC format" -LogLevel Error
    Add-LogEntry -Entry "$_" -LogLevel Debug
}

# Get apps if required
if ($IncludeApps) {
        try {
            Add-LogEntry -Entry "Getting device owners and their apps" -LogLevel Info
            $ownedDevices = $juribaDevices | Where-Object -FilterScript {$_.owner -and (($_.owner -split '/')[ -1 ]).Trim() -ne ""}
            $deviceAppsTable = Get-IntuneDeviceApplicationTable `
                            -AccessToken $accessToken `
                            -OwnedDevices $ownedDevices `
                            -ImportId $EntraIdIntuneImportId    
    }
    catch {
            Add-LogEntry -Entry "Unable to retrieve devices owners and their apps" -LogLevel Error
            Add-LogEntry -Entry "$_" -LogLevel Debug
    }
}

# Get non-compliance data if required
if ($IncludeNonComplianceData) {
    try {
        Add-LogEntry -Entry "Getting non-compliant devices and their non-compliant policies" -LogLevel Info

        $DeviceProperties += @(
            "nonCompliantPolicies",
            "nonCompliantPolicyCount"
        )

        # Get list of non-compliant devices
        $nonCompliantDevices = Get-IntuneDeviceNonCompliant -AccessToken $accessToken

        # 2) Build summary lookup: deviceId -> summary object
        $deviceSummaryLookup = @{}
        foreach ($ncDevice in $nonCompliantDevices) {
            $deviceId = $ncDevice.id

            # Pull compliance policy states for device
            $devicePolicies = Get-IntuneDeviceCompliancePolicyState `
                -AccessToken $accessToken `
                -DeviceId $deviceId

            # Filter for non-compliance + exclude default policy
            $nonCompliantPoliciesForDevice = $devicePolicies |
                Where-Object {
                    $_.state -ne "compliant" -and
                    $_.displayName -ne "Default Device Compliance Policy"
                } |
                Select-Object -Property id, displayName -Unique

            # Build a per-device summary row and store it in the lookup
            $deviceSummaryLookup[$deviceId] = [pscustomobject]@{
                deviceId = $deviceId
                nonCompliantPolicies = if ($nonCompliantPoliciesForDevice) { ($nonCompliantPoliciesForDevice.displayName -join ', ') } else { $null }
                nonCompliantPolicyCount = if ($nonCompliantPoliciesForDevice) { $nonCompliantPoliciesForDevice.Count } else { 0 }
            }
        }

        # Build a PSCustomObject collection for all devices in $juribaDevices
        $juribaDeviceNonCompliance = foreach ($device in $juribaDevices) {

            $deviceId = $device.uniqueIdentifier
            $summary  = $deviceSummaryLookup[$deviceId]

            [pscustomobject]@{
                deviceId = $deviceId
                nonCompliantPolicies = if ($summary) { $summary.nonCompliantPolicies } else { $null }
                nonCompliantPolicyCount = if ($summary) { $summary.nonCompliantPolicyCount } else { 0 }
            }
        }

        Add-LogEntry -Entry "Built non-compliance dataset for $($juribaDeviceNonCompliance.Count) devices" -LogLevel Info

        # Count of non-compliant devices
        $withPolicies = ($juribaDeviceNonCompliance | Where-Object { $_.nonCompliantPolicyCount -gt 0 }).Count
        Add-LogEntry -Entry "Devices with non-compliant policies: $withPolicies" -LogLevel Info
    }
    catch {
        Add-LogEntry -Entry "Unable to retrieve/build non-compliance data" -LogLevel Error
        Add-LogEntry -Entry "$_" -LogLevel Debug
    }
    try {
        Add-LogEntry -Entry "Appending compliance data to Juriba devices" -LogLevel Info
        $complianceTable = Convert-JuribaDevicesAddIntuneCompliance -JuribaDevices $juribaDevices -Summary $juribaDeviceNonCompliance
        $juribaDevices = $complianceTable
    }
    catch {
        Add-LogEntry -Entry "Unable to append compliance data to Juriba devices" -LogLevel Error
        Add-LogEntry -Entry "$_" -LogLevel Debug
    }
    
}

# Push devices to Juriba DPC
try {
    Add-LogEntry -Entry "Pushing devices to Juriba DPC" -LogLevel Info
    Invoke-JuribaAPIBulkImportDeviceFeedDataTableDiff `
    -Instance $Instance `
    -APIKey $ApiKey `
    -DPCDeviceDataTable $juribaDevices `
    -DPCUserDataTable $juribaUsers `
    -DPCDeviceAppDataTable $deviceAppsTable `
    -Properties $DeviceProperties `
    -ImportId $EntraIdIntuneImportId `
}
catch {
    Add-LogEntry -Entry "Unable to push devices to Juriba DPC" -LogLevel Error
    Add-LogEntry -Entry "$_" -LogLevel Debug
}

# Complete script
Add-LogEntry -Entry "Completing script"
Disconnect-Juriba