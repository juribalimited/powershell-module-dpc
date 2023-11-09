<#
.SYNOPSIS
A sample script to query a CSV file for users/groups and link them as group members
.DESCRIPTION
A sample script to query a CSV file users/groups and link them as group members within Juriba Platform.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$JuribaInstance,
    [Parameter(Mandatory=$true)]
    [string]$JuribaAPIKey,
    [Parameter(Mandatory=$true)]
    [string]$JuribaFeedName,
    [Parameter(Mandatory=$true)]
    [string]$ParentGroupName,
    [Parameter(Mandatory=$true)]
    [string]$Path
)

#Requires -Version 7
#Requires -Module @{ ModuleName = 'Juriba.Platform'; ModuleVersion = '0.0.39.0' }

$DashworksParams = @{
    Instance = $JuribaInstance
    APIKey = $JuribaAPIKey
}

# Get Juriba User Import feed
$feed = Get-JuribaImportUserFeed @DashworksParams -Name $JuribaFeedName
# If it doesnt exist, exit
if (-Not $feed) {
    Write-Error "Juriba import feed with name: $JuribaFeedName not found. Script will terminate."
    Exit
}
$importId = $feed.id

# Get Juriba Parent Group
$group = Get-JuribaImportGroup @DashworksParams -Name $ParentGroupName -ImportId $importId -ErrorAction SilentlyContinue -InfoLevel Full
$uniqueIdentifier = $group.uniqueIdentifier
# If it doesnt exist, exit
if (-Not $group) {
    Write-Error "Juriba Group with name: $JuribaFeedName not found within import: $JuribaFeedName. Script will terminate."
    Exit
}

Write-Information ("Using feed id {0}" -f $importId) -InformationAction Continue

# Get data from CSV file
$csvFile = Import-Csv -Path $Path

$i = 0
$membersList = New-Object System.Collections.Generic.List[System.Object]
foreach ($line in $csvFile) {
    $i++
    Write-Progress -Activity "Adding group members to members list" -Status ("Processing group member: {0}" -f $line) -PercentComplete (($i/$csvFile.Count*100))
    $membersList.Add($line)
}
if ($membersList.Count -gt 0) {
    $group = $group | Select-Object -Property * -ExcludeProperty uniqueIdentifier 
    $group.members = $membersList
    Set-JuribaImportGroup @DashworksParams -ImportId $importId -UniqueIdentifier $uniqueIdentifier -JsonBody ($group | ConvertTo-Json)
} else {
    Write-Error ("No members found in CSV. Script will terminate.")
}