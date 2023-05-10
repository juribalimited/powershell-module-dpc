<#

.SYNOPSIS
A sample script to query the MECM database for Applications and import
those as applications into Juriba platform. Ingests MECM data with CI_ID as the Unique Identifier. 

.DESCRIPTION
A sample script to query the MECM database for Applications and import
those as applications into Juriba platform. Script will either update or create the applications.
Must update variables below appropriately. Script will work for on-premise or Cloud installations of Juriba provided access to MECM instance is possible.
Must be run in the same directory as "MECM App Application With CI_ID Import.ps1"

Must add the following custom fields into Juriba platform BEFORE using this script:

New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - App Name' -CSVColumnHeader 'AppM - App Name' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - App Version' -CSVColumnHeader 'AppM - App Version' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Direct Link' -CSVColumnHeader 'AppM - Direct Link' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Test Status' -CSVColumnHeader 'AppM - Test Status' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Test Result' -CSVColumnHeader 'AppM - Test Result' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Test OS' -CSVColumnHeader 'AppM - Test OS' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - App Manufacturer' -CSVColumnHeader 'AppM - App Manufacturer' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Virtual Machine Name' -CSVColumnHeader 'AppM - Virtual Machine Name' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Test Time Taken' -CSVColumnHeader 'AppM - Test Time Taken' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Test Start Time' -CSVColumnHeader 'AppM - Test Start Time' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Old Test Data' -CSVColumnHeader 'AppM - Old Test Data' -Type LargeText -ObjectTypes Application -AllowUpdate 'ETL'

New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'CI_UniqueID' -CSVColumnHeader 'CI_UniqueID' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'PackageID' -CSVColumnHeader 'PackageID' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'


#>

#requires -Version 7
#requires -Modules Juriba.Platform

$dwAppImportFeedName = ""
$dwInstance = "https://changeme.com:8443"
$dwToken = "<<API KEY>>"
$dwAppImportScript = "$PSScriptRoot\MECM App Application With CI_ID Import.ps1"
$mecmInstance = "<<MECM FQDN>>"
$mecmDBName = "<<DB NAME>>"
$mecmUser = "<<MECM USER>>"
$mecmPw = "<<MECM PASSWORD>>"

$reqCustomFields = @("AppM - App Name","AppM - App Version", "AppM - Direct Link", "AppM - Test Status", "AppM - Test Result", "AppM - Test OS", "AppM - App Manufacturer", "AppM - Virtual Machine Name", "AppM - Test Time Taken", "AppM - Test Start Time", "AppM - Old Test Data", "CI_UniqueID", "PackageID")

###################
# Dashworks stuff #
###################

$customFields = Get-JuribaCustomField -Instance $dwInstance -APIKey $dwToken

foreach ($customField in $reqCustomFields) {
    if ($customField -notin $customFields.name) {
        Write-Error "Custom field: $customField missing from Juriba platform instance. Please onboard before proceeding."
    }
}

$mecmPwSs = ConvertTo-SecureString $mecmPw -AsPlainText -Force
$mecmCred = New-Object System.Management.Automation.PSCredential ($mecmUser, $mecmPwSs)

if (!(Get-InstalledModule -Name Juriba.Platform)) {
    Write-Host 'Juriba.Platform module not installed.'
    Install-Module -Name Juriba.Platform -Force
}

Write-Host 'Onboarding MECM App Data into Juriba Platform...'
& $dwAppImportScript -DwInstance $dwInstance -DwAPIKey $dwToken -DwFeedName $dwAppImportFeedName -MecmServerInstance $mecmInstance -MecmDatabaseName $mecmDBName -MecmCredentials $mecmCred