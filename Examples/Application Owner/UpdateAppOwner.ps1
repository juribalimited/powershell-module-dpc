[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$DpcInstance,
    [Parameter(Mandatory=$true)]
    [string]$DpcApiKey,
    [Parameter(Mandatory=$true)]
    [string]$AoInstance,
    [Parameter(Mandatory=$true)]
    [string]$AoApiKey,
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 10000)]
    [int]$InputBatchLength = 10000,
    [Parameter(Mandatory=$false)]
    [ValidateScript({
        if ($_ -ge 0) {
            $true
        } else {
            throw "Value must be greater than or equal to 0."
        }
    })]
    [int]$InputBatchStartOffset = 0,
    [Parameter(Mandatory=$false)]
    [ValidateScript({
        if ($_ -ge 0) {
            $true
        } else {
            throw "Value must be greater than or equal to 0."
        }
    })]
    [int]$MaximumAppsToImport = 0,
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 10000)]
    [int]$OutputBatchLength = 10000
)

#Requires -Version 7
#Requires -Module @{ ModuleName = 'Juriba.DPC'; ModuleVersion = '1.0.0.1' }

$InformationPreference = 'Continue'

Update-ApplicationOwner `
    -DpcInstance $DpcInstance `
    -DpcApiKey $DpcApiKey `
    -AoInstance $AoInstance `
    -AoApiKey $AoApiKey `
    -InputBatchLength $InputBatchLength `
    -InputBatchStartOffset $InputBatchStartOffset `
    -MaximumAppsToImport $MaximumAppsToImport `
    -OutputBatchLength $OutputBatchLength