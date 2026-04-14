<#
.SYNOPSIS
PowerShell module to retrieve Entra ID and Intune data via Microsoft Graph and prepare it for import into Juriba via the Juriba API.

.DESCRIPTION
This module provides cmdlets for:
- Authenticating to Microsoft Graph (client credentials)
- Retrieving datasets from Microsoft Entra ID and Microsoft Intune using Microsoft Graph
- Transforming Graph datasets into DPC-compatible DataTables for Juriba ingestion
- Supporting import workflows that submit prepared datasets to Juriba via the Juriba API

The module is structured with public functions stored under .\Public and internal helper functions stored under .\Private.
At import time, the module dot-sources all function files and exports only the public cmdlets.

DISCOVERY
To list all cmdlets exported by this module:
  Get-Command -Module Juriba.DPC.Graph

To view help for a specific cmdlet:
  Get-Help <CmdletName> -Full

.EXAMPLE
Import-Module Juriba.DPC.Graph
Get-Command -Module Juriba.DPC.Graph

Imports the module and lists available cmdlets.

.EXAMPLE
# Typical pattern: authenticate -> retrieve -> transform -> (import)
$tokenResponse = Get-GraphOAuthToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
$accessToken   = $tokenResponse.access_token

$usersDt = Get-EntraIdUser -AccessToken $accessToken
$juribaUsersDt = Convert-EntraIdUsersToJuribaDPC -Rows $usersDt.Rows -IncludeProperties "department","jobTitle","onPremises*"

Demonstrates a common workflow using Graph retrieval and conversion to a DPC-compatible table.

.NOTES
Requirements:
- PowerShell 7.1+
- Microsoft Graph permissions appropriate to the datasets being retrieved
- Network access to Microsoft Graph and the Juriba API

Conventions:
- Cmdlets prefixed Get-EntraId* and Get-Intune* retrieve data from Microsoft Graph.
- Cmdlets prefixed Convert-*ToJuribaDPC transform Graph datasets into DPC-compatible DataTables.
- Additional cmdlets may implement submission/import to Juriba via the Juriba API.

#>

# Requires -Version 7.1
Set-StrictMode -Version Latest

# Get public and private function definition files
$publicFunctions  = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -Exclude "*.Tests.*" -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -Exclude "*.Tests.*" -ErrorAction SilentlyContinue)

# Import all functions
foreach ($functionFile in @($publicFunctions + $privateFunctions)) {
    try {
        Write-Verbose "Importing $($functionFile.FullName)..."
        . $functionFile.FullName
    }
    catch {
        Write-Error "Failed to import function $($functionFile.FullName): $_"
    }
}

# Export public functions only
Export-ModuleMember -Function $publicFunctions.BaseName -Alias *