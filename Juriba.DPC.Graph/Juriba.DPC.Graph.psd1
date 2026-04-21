@{
    RootModule        = 'Juriba.DPC.Graph.psm1'
    ModuleVersion     = '0.0.0.1'
    GUID              = '40065a1b-815f-47d4-be2e-b5543bed9023'
    Author            = 'Juriba'
    CompanyName       = 'Juriba'
    Copyright         = '(c) Juriba. All rights reserved.'
    Description       = 'PowerShell Module to integrate Juriba DPC with Microsoft Graph API.'
    PowerShellVersion = '7.1'

    FunctionsToExport = @(
        'Convert-EntraIdGroupsToJuribaDPC',
        'Convert-EntraIdUsersToJuribaDPC',
        'Convert-IntuneAppsToJuribaDPC',
        'Convert-IntuneDevicesToJuribaDPC',
        'Convert-JuribaDevicesAddIntuneApplication',
        'Convert-JuribaDevicesAddIntuneCompliance',
        'Get-EntraIDGroup',
        'Get-EntraIdGroupMember',
        'Get-EntraIdUser',
        'Get-EntraIdUserAssignment',
        'Get-EntraIdUserAttribute',
        'Get-EntraIdUserGroupMember',
        'Get-EntraIdGroupMembershipTable',
        'Get-GraphOAuthToken',
        'Get-IntuneApplication',
        'Get-IntuneDevice',
        'Get-IntuneDeviceApplication',
        'Get-IntuneDeviceApplicationTable',
        'Get-IntuneDeviceCompliancePolicyState',
        'Get-IntuneDeviceCompliancePolicySettingStateSummary',
        'Get-IntuneDeviceMobile',
        'Get-IntuneDeviceNonComplianceTable',
        'Get-IntuneDeviceNonCompliant',
        'Get-IntuneManagedApplication'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('Juriba', 'DPC', 'Graph', 'Intune', 'Azure', 'Migration', 'Automation', 'PowerShell', 'API', 'Entra')
            LicenseUri   = 'https://raw.githubusercontent.com/juribalimited/powershell-module-dpc/main/LICENSE'
            ProjectUri   = 'https://github.com/juribalimited/powershell-module-dpc'
            IconUri      = 'https://raw.githubusercontent.com/juribalimited/powershell-module-dpc/main/resources/juriba_logo.jpeg'
            ReleaseNotes = 'Initial release of Juriba DPC Graph API integration module.'
        }
    }
}