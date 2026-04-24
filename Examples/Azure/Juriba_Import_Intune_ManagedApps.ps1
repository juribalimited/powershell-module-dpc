<#
.SYNOPSIS
Imports Intune-managed application metadata into Juriba DPC.

.DESCRIPTION
This script authenticates to Microsoft Entra ID using application credentials,
retrieves managed application data from Microsoft Intune via Microsoft Graph,
transforms the data into a Juriba DPC-compatible format, and uploads it to Juriba
using the DPC bulk import API.

.PARAMETER TenantId
The Microsoft Entra ID tenant ID used to acquire a Microsoft Graph access token.

.PARAMETER ClientId
The application (client) ID registered in Microsoft Entra ID.

.PARAMETER ClientSecret
The client secret associated with the Entra ID application registration.

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

.PARAMETER AppProperties
An array of application properties to include when transforming Intune
application data for Juriba DPC. Defaults to a standard set of commonly useful
metadata fields.

.OUTPUTS
None. Data is imported directly into Juriba DPC.

.EXAMPLE
.\Juriba_Import_Intune_ManagedApps.ps1 `
    -TenantId "00000000-0000-0000-0000-000000000000" `
    -ClientId "11111111-1111-1111-1111-111111111111" `
    -ClientSecret "client-secret-value"

.EXAMPLE
.\Juriba_Import_Intune_ManagedApps.ps1 `
    -TenantId "00000000-0000-0000-0000-000000000000" `
    -ClientId "11111111-1111-1111-1111-111111111111" `
    -ClientSecret "client-secret-value" `
    -AppProperties @("description","developer","publishingState")

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
    [string[]]$AppProperties = @(
        "description",
        "developer",
        "lastModifiedDateTime",
        "informationUrl",
        "publishingState",
        "channel",
        "fileName"
    )
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

# Get managed apps
try {
    Add-LogEntry -Entry "Getting managed applications" -LogLevel Info
    $apps = Get-IntuneManagedApplication `
        -AccessToken $accessToken `
        -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps"
}
catch {
    Add-LogEntry -Entry "Unable to retrieve managed applications" -LogLevel Error
    Add-LogEntry -Entry "$_" -LogLevel Debug
}

# Convert apps to Juriba DPC
try {
    Add-LogEntry -Entry "Converting apps to Juriba DPC format" -LogLevel Info
    $juribaApps = Convert-IntuneAppsToJuribaDPC `
    -Rows $apps `
    -IncludeProperties $AppProperties     
}
catch {
    Add-LogEntry -Entry "Unable to convert apps to Juriba DPC format" -LogLevel Error
    Add-LogEntry -Entry "$_" -LogLevel Debug
}

# Push apps to Juriba DPC
try {
    Add-LogEntry -Entry "Pushing apps to Juriba DPC" -LogLevel Info
    Invoke-JuribaAPIBulkImportApplicationFeedDataTableDiff `
    -Instance $Instance `
    -APIKey $ApiKey `
    -DPCApplicationDataTable $juribaApps `
    -ImportId $EntraIdIntuneImportId `
    -Properties $AppProperties
}
catch {
    Add-LogEntry -Entry "Unable to push apps to Juriba DPC" -LogLevel Error
    Add-LogEntry -Entry "$_" -LogLevel Debug
}

# Complete script
Add-LogEntry -Entry "Completing script"
Disconnect-Juriba