<#
    .SYNOPSIS
    Exports custom field definitions from a Juriba DPC instance to a JSON file.

    .DESCRIPTION
    Reads every custom field definition (or those whose name matches -NameLike) from a Juriba DPC
    instance and writes them to a JSON file. Use Import-JuribaCustomFields.ps1 to import the file
    into another instance.

    Each field is exported with the settings needed to recreate it:
    name, CSV column header, value type, object types, active state, update source and
    whether external updates are allowed. Instance-specific ids are not exported.

    .PARAMETER Instance
    Juriba DPC instance to export from. For example, https://dev.dpc.juriba.app

    .PARAMETER APIKey
    API key for the instance.

    .PARAMETER OutputPath
    Path of the JSON file to write.

    .PARAMETER NameLike
    Optional. Only export custom fields whose name matches this wildcard pattern. Defaults to all fields.

    .EXAMPLE
    PS> .\Export-JuribaCustomFields.ps1 -Instance "https://dev.dpc.juriba.app" -APIKey "xxxxx" -OutputPath .\customfields.json

    .EXAMPLE
    PS> .\Export-JuribaCustomFields.ps1 -Instance "https://dev.dpc.juriba.app" -APIKey "xxxxx" -OutputPath .\customfields.json -NameLike 'MyTeam_*'

    .NOTES
    This is an example script. Read it and try it on a test instance before using it in production.
    Requires Juriba.DPC 1.1.20.0 or later.
#>
#requires -Version 7
#requires -Modules @{ ModuleName = 'Juriba.DPC'; ModuleVersion = '1.1.20.0' }
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Instance,
    [Parameter(Mandatory = $true)]
    [string]$APIKey,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [Parameter(Mandatory = $false)]
    [string]$NameLike = '*'
)

$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['*-Juriba*:ErrorAction'] = 'Stop'

$valueTypes = @{ 1 = 'Text'; 2 = 'MultiText'; 3 = 'LargeText'; 4 = 'Date'; 5 = 'Number' }
$updateSources = @{ 1 = 'Directly'; 2 = 'ETL' }

$dpc = @{ Instance = $Instance; APIKey = $APIKey }

# The list call omits some settings (e.g. allowExternalUpdate), so read each field individually.
$allFields = Get-JuribaCustomField @dpc
$selected = @($allFields | Where-Object { $_.name -like $NameLike } | Sort-Object displayOrder)

Write-Information ("Found {0} custom field(s) on {1}; {2} match '{3}'." -f @($allFields).Count, $Instance, $selected.Count, $NameLike) -InformationAction Continue

$exported = foreach ($field in $selected) {
    $detail = Get-JuribaCustomField @dpc -CustomFieldId $field.id

    $objectTypes = @(
        if ($detail.isComputerField)    { 'Device' }
        if ($detail.isUserField)        { 'User' }
        if ($detail.isApplicationField) { 'Application' }
        if ($detail.isMailboxField)     { 'Mailbox' }
    )

    [ordered]@{
        name                = $detail.name
        csvColumnHeader     = $detail.csvUpdateColumnHeader
        type                = $valueTypes[[int]$detail.valueTypeId]
        objectTypes         = $objectTypes
        isActive            = [bool]$detail.isActive
        allowUpdate         = $updateSources[[int]$detail.updateSourceId]
        allowExternalUpdate = [bool]$detail.allowExternalUpdate
        displayOrder        = $detail.displayOrder
    }
}

$export = [ordered]@{
    exportedFrom = $Instance
    exportedAt   = (Get-Date).ToUniversalTime().ToString('o')
    dpcVersion   = (Get-JuribaDPCVersion -Instance $Instance).ToString()
    nameFilter   = $NameLike
    fieldCount   = @($exported).Count
    customFields = @($exported)
}

$export | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding utf8

Write-Information ("Exported {0} custom field(s) to {1}." -f $export.fieldCount, (Resolve-Path $OutputPath)) -InformationAction Continue
