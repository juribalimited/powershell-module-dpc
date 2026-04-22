<#

.SYNOPSIS
A sample script to bulk update task values across multiple objects from a CSV file.

.DESCRIPTION
A sample script demonstrating how to use Set-JuribaTaskValueBulk and
Get-JuribaTaskBulkUpdateLog to update task values for many objects in a
single API call per task.

The script reads a CSV file containing object keys, task IDs, task types, and
values, groups the updates by task, and performs a bulk update for each group.

CSV format:
    ObjectKey,TaskId,TaskType,Value
    9141,13188,Select,5
    5123,13188,Select,5
    9141,13265,Date,2026-04-15
    5123,13760,Text,Migrated

TaskType must be one of: Select, Date, Text

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$Instance,
    [Parameter(Mandatory=$true)]
    [string]$APIKey,
    [Parameter(Mandatory=$true)]
    [int]$ProjectId,
    [Parameter(Mandatory=$true)]
    [ValidateSet("Device", "User", "Application", "Mailbox")]
    [string]$ObjectType,
    [Parameter(Mandatory=$true)]
    [string]$Path
)

#Requires -Version 7
#Requires -Module @{ ModuleName = 'Juriba.DPC'; ModuleVersion = '1.1.15' }

$juribaParams = @{
    Instance = $Instance
    APIKey   = $APIKey
}

# Import the CSV and group by TaskId
$updates = Import-Csv -Path $Path
$grouped = $updates | Group-Object TaskId

Write-Host "Found $($grouped.Count) task(s) to update across $($updates.Count) total rows."

$operations = @()

foreach ($group in $grouped) {
    $taskId   = [int]$group.Name
    $items    = $group.Group | ForEach-Object { [int]$_.ObjectKey }
    $sample   = $group.Group[0]
    $taskType = $sample.TaskType

    Write-Host "Updating TaskId $taskId ($taskType) for $($items.Count) objects..."

    $bulkParams = @{
        ProjectId  = $ProjectId
        TaskId     = $taskId
        ObjectType = $ObjectType
        Objects    = $items
    }

    switch ($taskType) {
        "Select" { $bulkParams['SelectValue'] = [int]$sample.Value }
        "Date"   { $bulkParams['DateValue'] = $sample.Value }
        "Text"   { $bulkParams['TextValue'] = $sample.Value }
        default  { Write-Warning "Unknown TaskType '$taskType' for TaskId $taskId. Skipping."; continue }
    }

    $result = Set-JuribaTaskValueBulk @juribaParams @bulkParams

    Write-Host "  Submitted: opId=$($result.opId), itemsSent=$($result.itemsCountSent), itemsAccepted=$($result.itemsCountAccepted)"
    $operations += $result
}

# Poll for completion of all operations
Write-Host "`nChecking bulk update logs..."

foreach ($op in $operations) {
    $maxAttempts = 30
    $attempt = 0
    do {
        Start-Sleep -Seconds 2
        $log = Get-JuribaTaskBulkUpdateLog @juribaParams -OperationId $op.opId
        $attempt++
    } until ($log.results.outcome.status -eq 2 -or $attempt -ge $maxAttempts)

    if ($log.results.outcome.status -eq 2) {
        Write-Host "  opId $($op.opId): $($log.results.outcome.text) - Task '$($log.results.taskName)' updated $($log.results.objectCount) objects"
    } else {
        Write-Warning "  opId $($op.opId): Did not complete within expected time. Last status: $($log.results.outcome.text)"
        if ($log.results.error) {
            Write-Warning "  Error: $($log.results.error)"
        }
    }
}

Write-Host "`nBulk update complete."
