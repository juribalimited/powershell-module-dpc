[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$Instance,
    [Parameter(Mandatory = $true)]
    [string]$APIKey,
    [Parameter(Mandatory = $false)]
    [string]$InputPath = ".\lists.json",
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = ".\list-import-report.csv",
    [Parameter(Mandatory = $false)]
    [string]$NameSuffix,
    [Parameter(Mandatory = $false)]
    [switch]$Overwrite,
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

#Requires -Version 7
#Requires -Module @{ ModuleName = 'Juriba.DPC'; ModuleVersion = '1.1.25.0' }

# Creates lists on a Juriba DPC instance from a file made by "Export Lists.ps1".
# Run with -DryRun first to see what would be created and what would be skipped.
# See README.md.

$InformationPreference = 'Continue'

$importParams = @{
    Instance   = $Instance
    APIKey     = $APIKey
    Path       = $InputPath
    NameSuffix = $NameSuffix
    Overwrite  = $Overwrite
    WhatIf     = $DryRun
}

if ($DryRun) {
    Write-Information "Dry run: nothing will be created."
}
Write-Information "Importing lists into $Instance. Reading field and filter definitions can take a minute per object type."
$results = @(Import-JuribaListDefinition @importParams -ErrorAction Stop)

$results |
    Select-Object SourceListId, ListName, ObjectType, Status, TargetListId,
        @{ Name = 'MissingReferences'; Expression = { @($_.MissingReferences) -join '; ' } }, Reason |
    Export-Csv -Path $ReportPath -Encoding utf8

Write-Information ""
$results | Group-Object Status | ForEach-Object { Write-Information ("{0,-14} {1}" -f $_.Name, $_.Count) }
foreach ($skipped in $results | Where-Object Status -in 'Skipped', 'Failed', 'CreatedBroken') {
    Write-Warning ("{0} '{1}': {2}" -f $skipped.Status, $skipped.ListName, $skipped.Reason)
    foreach ($missing in @($skipped.MissingReferences)) {
        Write-Warning ("    missing: {0}" -f $missing)
    }
}
Write-Information ("Report written to {0}" -f (Resolve-Path $ReportPath))
