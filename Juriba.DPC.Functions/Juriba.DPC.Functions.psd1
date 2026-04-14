@{
    RootModule        = 'Juriba.DPC.Functions.psm1'
    ModuleVersion     = '0.0.0.1'
    GUID              = '5fc773e3-ccf7-45a5-a20f-bac672677e74'
    Author            = 'Juriba'
    CompanyName       = 'Juriba'
    Copyright         = '(c) Juriba. All rights reserved.'
    Description       = 'PowerShell Module to integrate Juriba DPC with external systems.'
    PowerShellVersion = '7.1'

    FunctionsToExport = @(
        'ConvertTo-DataTable',
        'Merge-DataTable',
        'Invoke-JuribaAPIBulkImportApplicationFeedDataTableDiff',
        'Invoke-JuribaAPIBulkImportDeviceFeedDataTableDiff',
        'Invoke-JuribaAPIBulkImportGroupFeedDataTableDiff',
        'Invoke-JuribaAPIBulkImportUserFeedDataTableDiff'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('Juriba', 'DPC', 'Migration', 'Automation', 'PowerShell', 'API')
            LicenseUri   = 'https://raw.githubusercontent.com/juribalimited/powershell-module-dpc/main/LICENSE'
            ProjectUri   = 'https://github.com/juribalimited/powershell-module-dpc'
            IconUri      = 'https://raw.githubusercontent.com/juribalimited/powershell-module-dpc/main/resources/juriba_logo.jpeg'
            ReleaseNotes = 'Initial release of Juriba DPC Functions integration module.'
        }
    }
}