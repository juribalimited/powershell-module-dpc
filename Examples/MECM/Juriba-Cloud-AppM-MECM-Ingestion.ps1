<#

.SYNOPSIS
A sample script to query the MECM database for Applications and import
those as applications into Juriba platform. Ingests MECM data with CI_ID as the Unique Identifier. 

.DESCRIPTION
A sample script to query the MECM database for Applications and import
those as applications into Juriba platform. Script will either update or create the applications.
Must update variables below appropriately. Script will work for on-premise or Cloud installations of Juriba provided access to MECM instance is possible.
Must be run in the same directory as "MECM App Application With CI_ID Import.ps1"

#>

#requires -Version 7
#requires -Modules Juriba.Platform

$dwAppImportFeedName = "<<CHANGE ME>>Juriba Application Import Feed Name"
$dwInstance = "https://change-me-juriba-fqdn.com:8443"
$dwToken = "<<CHANGE ME>>"
$dwAppImportScript = "$PSScriptRoot\MECM App Application With CI_ID Import.ps1"
$mecmInstance = "<<CHANGE ME>>"
$mecmDBName = "<<CHANGE ME>>"
$mecmUser = "<<CHANGE ME>>"
$mecmPw = "<<CHANGE ME>>"

###################
# Dashworks stuff #
###################
$mecmPwSs = ConvertTo-SecureString $mecmPw -AsPlainText -Force
$mecmCred = New-Object System.Management.Automation.PSCredential ($mecmUser, $mecmPwSs)

if (!(Get-InstalledModule -Name Juriba.Platform)) {
    Write-Host 'Juriba.Platform module not installed.'
    Install-Module -Name Juriba.Platform -Force
}

Write-Host 'Onboarding MECM App Data into Juriba Platform...'
& $dwAppImportScript -DwInstance $dwInstance -DwAPIKey $dwToken -DwFeedName $dwAppImportFeedName -MecmServerInstance $mecmInstance -MecmDatabaseName $mecmDBName -MecmCredentials $mecmCred