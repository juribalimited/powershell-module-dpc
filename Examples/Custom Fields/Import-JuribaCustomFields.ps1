<#
    .SYNOPSIS
    Imports custom field definitions exported by Export-JuribaCustomFields.ps1 into a Juriba DPC instance.

    .DESCRIPTION
    Compares each exported custom field with the target instance and decides what to do:

      Create    - no custom field on the target uses the CSV column header, so the field is created.
      Unchanged - the field already exists with the same settings, so nothing is done.
      Update    - the field exists but some settings differ (name, object types, active state,
                  update source or external updates). The differences are reported. The field is
                  only changed when -UpdateExisting is used.
      Conflict  - the field cannot be safely created or updated, for example the value type differs
                  or the name is already used by a field with a different CSV column header.
                  Conflicts are reported and never changed.

    Fields are matched on CSV column header, which DPC requires to be unique. Names do not have to be unique in DPC.

    Run with -WhatIf first to preview the changes without making any.
    After importing, every exported field is read back from the target and checked.

    .PARAMETER Instance
    Juriba DPC instance to import into. For example, https://prod.dpc.juriba.app

    .PARAMETER APIKey
    API key for the instance.

    .PARAMETER InputPath
    JSON file created by Export-JuribaCustomFields.ps1.

    .PARAMETER UpdateExisting
    Optional. Update existing fields whose settings differ from the export. Without this switch the differences are only reported.

    .PARAMETER ReportPath
    Optional. Path of a CSV report listing each field, the action taken and the validation result.

    .EXAMPLE
    PS> .\Import-JuribaCustomFields.ps1 -Instance "https://prod.dpc.juriba.app" -APIKey "xxxxx" -InputPath .\customfields.json -WhatIf

    .EXAMPLE
    PS> .\Import-JuribaCustomFields.ps1 -Instance "https://prod.dpc.juriba.app" -APIKey "xxxxx" -InputPath .\customfields.json -UpdateExisting -ReportPath .\import-report.csv

    .NOTES
    This is an example script. Read it and try it on a test instance before using it in production.
    Always run with -WhatIf first. The import never deletes custom fields or changes the value type of an existing field,
    and only changes existing fields when -UpdateExisting is used. There is no undo, so export the target instance first
    with Export-JuribaCustomFields.ps1 to keep a record of how it looked.
    Requires Juriba.DPC 1.1.20.0 or later.
#>
#requires -Version 7
#requires -Modules @{ ModuleName = 'Juriba.DPC'; ModuleVersion = '1.1.20.0' }
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Instance,
    [Parameter(Mandatory = $true)]
    [string]$APIKey,
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [Parameter(Mandatory = $false)]
    [switch]$UpdateExisting,
    [Parameter(Mandatory = $false)]
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
# Make errors from the Juriba.DPC cmdlets stop processing so they are caught and reported per field.
$PSDefaultParameterValues['*-Juriba*:ErrorAction'] = 'Stop'

$valueTypes = @{ 1 = 'Text'; 2 = 'MultiText'; 3 = 'LargeText'; 4 = 'Date'; 5 = 'Number' }
$updateSources = @{ 1 = 'Directly'; 2 = 'ETL' }
$dpc = @{ Instance = $Instance; APIKey = $APIKey }

function ConvertTo-PortableField {
    # Converts a full custom field definition from the API into the same shape as the export file.
    param($Detail)
    [pscustomobject]@{
        id                  = $Detail.id
        name                = $Detail.name
        csvColumnHeader     = $Detail.csvUpdateColumnHeader
        type                = $valueTypes[[int]$Detail.valueTypeId]
        objectTypes         = @(
            if ($Detail.isComputerField)    { 'Device' }
            if ($Detail.isUserField)        { 'User' }
            if ($Detail.isApplicationField) { 'Application' }
            if ($Detail.isMailboxField)     { 'Mailbox' }
        )
        isActive            = [bool]$Detail.isActive
        allowUpdate         = $updateSources[[int]$Detail.updateSourceId]
        allowExternalUpdate = [bool]$Detail.allowExternalUpdate
    }
}

function Compare-Field {
    # Returns the settings that differ between an exported field and a target field, keyed by Set-JuribaCustomField parameter name.
    param($Source, $Target)
    $diff = [ordered]@{}
    if ($Source.name -cne $Target.name) { $diff.Name = $Source.name }
    if ((@($Source.objectTypes | Sort-Object) -join ',') -ne (@($Target.objectTypes | Sort-Object) -join ',')) { $diff.ObjectTypes = [string[]]$Source.objectTypes }
    if ($Source.isActive -ne $Target.isActive) { $diff.IsActive = [bool]$Source.isActive }
    if ($Source.allowUpdate -ne $Target.allowUpdate) { $diff.AllowUpdate = $Source.allowUpdate }
    if ($Source.allowExternalUpdate -ne $Target.allowExternalUpdate) { $diff.AllowExternalUpdate = [bool]$Source.allowExternalUpdate }
    $diff
}

function Format-Diff {
    param($Diff, $Target)
    ($Diff.Keys | ForEach-Object {
        $current = switch ($_) {
            'Name'                { $Target.name }
            'ObjectTypes'         { $Target.objectTypes -join '+' }
            'IsActive'            { $Target.isActive }
            'AllowUpdate'         { $Target.allowUpdate }
            'AllowExternalUpdate' { $Target.allowExternalUpdate }
        }
        $wanted = if ($_ -eq 'ObjectTypes') { $Diff[$_] -join '+' } else { $Diff[$_] }
        "{0}: {1} -> {2}" -f $_, $current, $wanted
    }) -join '; '
}

function Get-TargetFieldMap {
    # Returns full definitions of every custom field on the target, keyed by CSV column header.
    $byHeader = @{}
    foreach ($f in @(Get-JuribaCustomField @dpc)) {
        $byHeader[$f.csvUpdateColumnHeader] = ConvertTo-PortableField (Get-JuribaCustomField @dpc -CustomFieldId $f.id)
    }
    $byHeader
}

# --- Load and check the export file -------------------------------------------------------------
$export = Get-Content -Path $InputPath -Raw | ConvertFrom-Json
$fields = @($export.customFields)
if ($fields.Count -ne $export.fieldCount) {
    throw ("Export file says it holds {0} field(s) but contains {1}. The file may be incomplete." -f $export.fieldCount, $fields.Count)
}
$duplicateHeaders = $fields | Group-Object csvColumnHeader | Where-Object Count -gt 1
if ($duplicateHeaders) {
    throw ("Export file contains duplicate CSV column headers: {0}" -f ($duplicateHeaders.Name -join ', '))
}
Write-Information ("Loaded {0} custom field(s) exported from {1} (DPC {2}) at {3}." -f $fields.Count, $export.exportedFrom, $export.dpcVersion, $export.exportedAt) -InformationAction Continue

# --- Plan -----------------------------------------------------------------------------------------
$target = Get-TargetFieldMap
$plan = foreach ($src in $fields) {
    $tgt = $target[$src.csvColumnHeader]
    $row = [ordered]@{ CSVColumnHeader = $src.csvColumnHeader; Name = $src.name; Action = $null; Details = ''; Result = ''; Validation = '' }

    if (-not $tgt) {
        $sameName = @($target.Values | Where-Object { $_.name -eq $src.name })
        if ($sameName) {
            $row.Action = 'Conflict'
            $row.Details = "Name already used on target by field id {0} with CSV column header '{1}'" -f $sameName[0].id, $sameName[0].csvColumnHeader
        }
        else {
            $row.Action = 'Create'
            $row.Details = "{0}; {1}; active={2}; update={3}; external={4}" -f $src.type, ($src.objectTypes -join '+'), $src.isActive, $src.allowUpdate, $src.allowExternalUpdate
        }
    }
    elseif ($src.type -ne $tgt.type) {
        $row.Action = 'Conflict'
        $row.Details = "Value type differs (export: {0}, target: {1}). The type of an existing field cannot be changed safely." -f $src.type, $tgt.type
    }
    else {
        $diff = Compare-Field -Source $src -Target $tgt
        if ($diff.Count -eq 0) {
            $row.Action = 'Unchanged'
        }
        else {
            $row.Action = 'Update'
            $row.Details = Format-Diff -Diff $diff -Target $tgt
        }
    }

    [pscustomobject]$row | Add-Member -NotePropertyMembers @{ Source = $src; TargetId = $tgt.id; Diff = $diff } -PassThru
    $diff = $null
}

Write-Information "`nPlanned changes:" -InformationAction Continue
$plan | Format-Table CSVColumnHeader, Name, Action, Details -AutoSize -Wrap | Out-String | Write-Information -InformationAction Continue
$plan | Group-Object Action | ForEach-Object { Write-Information ("  {0,-9} {1}" -f $_.Name, $_.Count) -InformationAction Continue }
if (($plan | Where-Object Action -eq 'Update') -and -not $UpdateExisting) {
    Write-Information "  Fields marked Update will only be reported. Run with -UpdateExisting to apply those changes." -InformationAction Continue
}

# --- Apply ----------------------------------------------------------------------------------------
foreach ($item in $plan) {
    $src = $item.Source
    try {
        switch ($item.Action) {
            'Create' {
                if ($PSCmdlet.ShouldProcess($src.csvColumnHeader, 'Create custom field')) {
                    $params = @{
                        Name                = $src.name
                        CSVColumnHeader     = $src.csvColumnHeader
                        Type                = $src.type
                        ObjectTypes         = [string[]]$src.objectTypes
                        IsActive            = [bool]$src.isActive
                        AllowUpdate         = $src.allowUpdate
                        AllowExternalUpdate = [bool]$src.allowExternalUpdate
                    }
                    New-JuribaCustomField @dpc @params -Confirm:$false
                    $item.Result = 'Created'
                }
                else { $item.Result = 'WhatIf' }
            }
            'Update' {
                if (-not $UpdateExisting) { $item.Result = 'Reported only' }
                elseif ($PSCmdlet.ShouldProcess($src.csvColumnHeader, 'Update custom field')) {
                    $params = $item.Diff
                    Set-JuribaCustomField @dpc -CustomFieldId $item.TargetId @params -Confirm:$false
                    $item.Result = 'Updated'
                }
                else { $item.Result = 'WhatIf' }
            }
            'Unchanged' { $item.Result = 'Skipped' }
            'Conflict'  { $item.Result = 'Skipped' }
        }
    }
    catch {
        $item.Result = 'Failed'
        $item.Details = "{0} | {1}" -f $item.Details, $_.Exception.Message
        Write-Warning ("{0}: {1}" -f $src.csvColumnHeader, $_.Exception.Message)
    }
}

# --- Validate -------------------------------------------------------------------------------------
if ($WhatIfPreference) {
    Write-Information "`n-WhatIf was used, so no changes were made and validation was skipped." -InformationAction Continue
}
else {
    $after = Get-TargetFieldMap
    foreach ($item in $plan) {
        $tgt = $after[$item.Source.csvColumnHeader]
        if (-not $tgt) {
            $item.Validation = 'FAIL: not found on target'
        }
        elseif ($item.Source.type -ne $tgt.type) {
            $item.Validation = "FAIL: type is {0}, export has {1}" -f $tgt.type, $item.Source.type
        }
        else {
            $diff = Compare-Field -Source $item.Source -Target $tgt
            $item.Validation = if ($diff.Count -eq 0) { 'PASS' } else { 'FAIL: ' + (Format-Diff -Diff $diff -Target $tgt) }
        }
    }

    $passed = @($plan | Where-Object Validation -eq 'PASS').Count
    Write-Information ("`nValidation: {0} of {1} exported field(s) match the target." -f $passed, $plan.Count) -InformationAction Continue
    $plan | Where-Object Validation -ne 'PASS' | Format-Table CSVColumnHeader, Action, Result, Validation -AutoSize -Wrap | Out-String | Write-Information -InformationAction Continue
    Write-Information "Note: display order is not imported. New fields are added after the target's existing fields." -InformationAction Continue
}

if ($ReportPath) {
    $plan | Select-Object CSVColumnHeader, Name, Action, Result, Validation, Details | Export-Csv -Path $ReportPath -NoTypeInformation
    Write-Information ("Report written to {0}." -f (Resolve-Path $ReportPath)) -InformationAction Continue
}
