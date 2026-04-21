# Juriba.DPC.Graph

PowerShell module to retrieve data from **Microsoft Entra ID** and **Microsoft Intune** via **Microsoft Graph**, transform it into **DPC-compatible** `System.Data.DataTable` outputs, and support ingestion into Juriba via the Juriba API.

This module is designed for automation scenarios (service-to-service, non-interactive) and follows a consistent pattern:

1. Authenticate to Microsoft Graph
2. Retrieve datasets (Entra ID / Intune)
3. Transform results into DPC-compatible tables
4. Optionally enrich/augment Juriba device datasets with Graph-derived data

---

## Key Features

- **Microsoft Graph authentication** using client credentials
- **Entra ID retrieval** (users, groups, group members, user memberships, assignments, attributes)
- **Intune retrieval** (managed devices, mobile devices, managed apps, device app intent/state, compliance states)
- **DPC-compatible transformations** from Graph datasets (fixed identity columns + optional dynamic scalar properties)
- **Relationship / summary table builders** (e.g., group membership mapping, device app mapping, non-compliance summaries)
- **Verbose diagnostic support** for paging and request tracing (`-Verbose`)

---

## Requirements

- PowerShell **7.1+**
- Entra ID App Registration configured for **client credentials**
- Microsoft Graph permissions appropriate to the datasets you pull
- Network access to:
  - `https://login.microsoftonline.com`
  - `https://graph.microsoft.com`
  - Juriba API endpoint (if you use API submission/import functions)

---

## Installation

### Local / internal installation

Place the module folder in one of the paths returned by:

```powershell
$env:PSModulePath -split ';'
```

Then import the module

```powershell
Import-Module Juriba.DPC.Graph -Force
Get-Command -Module Juriba.DPC.Graph
```

---

## Quick Start

1. Authenticate to Microsoft Graph

```powershell
$tokenResponse = Get-GraphOAuthToken `
  -TenantId $TenantId `
  -ClientId $ClientId `
  -ClientSecret $ClientSecret

$accessToken = $tokenResponse.access_token
```

2. Retrieve data from Entra ID / Intune

```powershell
# Entra ID users
$usersDt = Get-EntraIdUser -AccessToken $accessToken

# Intune devices
$devicesDt = Get-IntuneDevice -AccessToken $accessToken

# Intune managed applications
$appsDt = Get-IntuneManagedApplication -AccessToken $accessToken
```

3. Convert to Juriba DPC compatible tables

```powershell
# Convert Entra ID users to a DPC-compatible DataTable:
$juribaUsersDt = Convert-EntraIdUsersToJuribaDPC `
  -Rows $usersDt.Rows `
  -IncludeProperties "department","jobTitle","onPremises*"

# Convert Intune devices to a DPC-compatible DataTable:
$juribaUsersDt = Convert-IntuneDevicesToJuribaDPC `   
  -Rows $usersDt.Rows `
  -IncludeProperties "complianceState","ownerType","managementState"

# Convert Intune managed apps to a DPC-compatible DataTable:

$juribaAppsDt = Convert-IntuneAppsToJuribaDPC `
  -Rows $appsDt.Rows `
  -IncludeProperties "is*","owner*","minimum*"
```

---

## Common Workflows

### Entra ID: Groups and membership mapping

```powershell
$groupsDt = Get-EntraIDGroup -AccessToken $accessToken

$membershipDt = Get-EntraIdGroupMembershipTable `
  -AccessToken $accessToken `
  -Groups $groupsDt.Rows `
  -ImportId $ImportId
```

### Intune: Device application mapping (Graph beta dependency)

```powershell
$deviceAppsDt = Get-IntuneDeviceApplicationTable `
  -AccessToken $accessToken `
  -OwnedDevices $devicesDt.Rows `
  -ImportId $ImportId
```

### Intune: Compliance detail and non-compliance summaries

```powershell
# Per-device compliance policy state
$policyStates = Get-IntuneDeviceCompliancePolicyState `
  -AccessToken $accessToken `
  -DeviceId $DeviceId

# Setting-level evaluation for a specific device/policy
$settingStatesDt = Get-IntuneDeviceCompliancePolicySettingStateSummary `
  -AccessToken $accessToken `
  -DeviceId $DeviceId `
  -PolicyId $PolicyId

# Per-device summary of non-compliant policies
$nonComplianceDt = Get-IntuneDeviceNonComplianceTable `
  -AccessToken $accesstoken `
  -Devices $devicesDt.Rows
```

---

## Exported Cmdlets

The authoritative list is defined in the module manifest (Juriba.DPC.Graph.psd1) and can be displayed at runtime:

```powershell
(Get-Module Juriba.DPC.Graph -ListAvailable).ExportedCommands.Keys | Sort-Object
```

### Authentication

- Get-GraphOAuthToken

### Entra ID (Graph)

- Get-EntraIDGroup
- Get-EntraIdGroupMember
- Get-EntraIdGroupMembershipTable
- Get-EntraIdUser
- Get-EntraIdUserAssignment
- Get-EntraIdUserAttribute
- Get-EntraIdUserGroupMember

### Intune (Graph)

- Get-IntuneApplication
- Get-IntuneManagedApplication
- Get-IntuneDevice
- Get-IntuneDeviceMobile
- Get-IntuneDeviceApplication
- Get-IntuneDeviceApplicationTable
- Get-IntuneDeviceCompliancePolicyState
- Get-IntuneDeviceCompliancePolicySettingStateSummary
- Get-IntuneDeviceNonComplianceTable
- Get-IntuneDeviceNonCompliant

### DPC-compatible conversion / enrichment

- Convert-EntraIdGroupsToJuribaDPC
- Convert-EntraIdUsersToJuribaDPC
- Convert-IntuneAppsToJuribaDPC
- Convert-IntuneDevicesToJuribaDPC
- Convert-JuribaDevicesAddIntuneApplication
- Convert-JuribaDevicesAddIntuneCompliance

For full parameter documentation:

```powershell
Get-Help <CmdletName> -Full
```

---

## Output Conventions

This module generally follows these patterns:

- Bulk retrieval cmdlets typically return System.Data.DataTable
- Targeted lookups may return raw Graph objects (PSCustomObject)
- Converter and table builder cmdlets output DPC-compatible System.Data.DataTable objects
- Many cmdlets support -Verbose for paging and request tracing

---

## Permissions (high-level)

Required Microsoft Graph permissions depend on the datasets you call.

General guidance:

- Entra ID datasets require directory read permissions
- Intune datasets require Intune/DeviceManagement read permissions
- Some queries (e.g., transitive membership with $count=true) require special headers and may have additional permission considerations

Keep permission assignments minimal and aligned to the cmdlets you will run in production.

---

## Paging, Throttling, and Performance

- Many Graph endpoints return paged results; DataTable-based cmdlets commonly follow @odata.nextLink.
- In large tenants you may see throttling (HTTP 429) Consider:
  - Backoff/retry logic
  - Reduce request rates
  - Narrow queries where possible

---

## Microsoft Graph Beta Endpoints

Some cmdlets use Microsoft Graph beta endpoints (directly or indirectly). Beta endpoints can change without notice. If output properties change or become null, revalidate response shape and update transformation logic accordingly. All cmdlets provide a $Uri parameter, allowing the default endpoint to be overridden.

---

## Documentation

- Cmdlets include **comment-based help**
- An **about_help** topic is included:

```powershell
Get-Help about_Juriba.DPC.Graph -Full
```

---

## Troubleshooting

### 401 / 403 errors

- Token expired or invalid
- Missing Microsoft Graph permissions
- Admin consent not granted for application permissions

### Empty results

- Verify the calling principal has access to the relevant datasets
- Some cmdlets apply default filters (e.g., security-enabled groups only)

### Throttling (HTTP 429)

- Implement backoff/retry
- Reduce request frequency
- Narrow queries where possible

### Verbose Logging

```powershell
$VerbosePreference = "Continue"
```

---

## Contributing (internal)

Recommended practices:

- Keep cmdlets single-purpose (retrieve vs transform vs import/enrich)
- Maintain consistent output semantics (DataTable for bulk, raw objects for lookups)
- Keep help accurate and aligned with implementation
- Use appropriate terminology in Juriba-related documentation
