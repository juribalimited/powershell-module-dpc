[CmdletBinding(DefaultParameterSetName = "ByName")]
param (
    [Parameter(Mandatory = $true)]
    [string]$Instance,
    [Parameter(Mandatory = $true)]
    [string]$APIKey,
    [Parameter(Mandatory = $true, ParameterSetName = "ByName")]
    [string[]]$ListName,
    [Parameter(Mandatory = $true, ParameterSetName = "ById")]
    [int[]]$ListId,
    [Parameter(Mandatory = $true, ParameterSetName = "All")]
    [switch]$All,
    [Parameter(Mandatory = $false)]
    [ValidateSet("Device", "User", "Application", "Mailbox")]
    [string[]]$ObjectType = @("Device", "User", "Application", "Mailbox"),
    [Parameter(Mandatory = $false)]
    [switch]$ExcludeDependencies,
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\lists.json"
)

#Requires -Version 7
#Requires -Module @{ ModuleName = 'Juriba.DPC'; ModuleVersion = '1.1.25.0' }

# Exports dynamic list definitions from a Juriba DPC instance to a JSON file that
# "Import Lists.ps1" can load into another instance. See README.md.

$InformationPreference = 'Continue'

$exportParams = @{
    Instance            = $Instance
    APIKey              = $APIKey
    ObjectType          = $ObjectType
    ExcludeDependencies = $ExcludeDependencies
}
switch ($PSCmdlet.ParameterSetName) {
    "ByName" { $exportParams.ListName = $ListName }
    "ById"   { $exportParams.ListId = $ListId }
    "All"    { $exportParams.All = $true }
}

Write-Information "Exporting lists from $Instance. Reading field and filter definitions can take a minute per object type."
$export = Export-JuribaListDefinition @exportParams -ErrorAction Stop

if (-not $export -or @($export.lists).Count -eq 0) {
    Write-Warning "No lists were exported."
    return
}

$export | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding utf8
Write-Information ("Exported {0} list(s) to {1}:" -f @($export.lists).Count, (Resolve-Path $OutputPath))
$export.lists | ForEach-Object {
    Write-Information ("  [{0}] {1} ({2}, {3})" -f $_.sourceListId, $_.listName, $_.objectType, $_.listType)
}
