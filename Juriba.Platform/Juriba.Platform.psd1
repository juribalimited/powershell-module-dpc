#
# Module manifest for module 'Juriba.Platform'
#
# Generated by: Juriba
#
# Generated on: 02/12/2021
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule        = 'Juriba.Platform.psm1'

    # Version number of this module.
    ModuleVersion     = '0.0.48.0'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID              = '8af9334c-a441-4e08-acb7-46f93a1d2231'

    # Author of this module
    Author            = 'Juriba'

    # Company or vendor of this module
    CompanyName       = 'Juriba'

    # Copyright statement for this module
    Copyright         = '(c) Juriba. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'PowerShell Module to interact with Juriba Platform.'

    # Minimum version of the PowerShell engine required by this module
    # PowerShellVersion = ''

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # ClrVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    # PS> (Get-ChildItem -Path .\Juriba.Platform\Public\*.ps1).Basename | Join-String -Separator ",`r`n" -SingleQuote
    FunctionsToExport = @(
        'Add-JuribaCustomFieldValue',
        'Add-JuribaListTag',
        'Connect-Juriba',
        'Disconnect-Juriba',
        'Export-JuribaList',
        'Get-JuribaApplicationV1',
        'Get-JuribaAutomation',
        'Get-JuribaAutomationAction',
        'Get-JuribaBucket',
        'Get-JuribaCapacitySlot',
        'Get-JuribaCapacityUnit',
        'Get-JuribaCustomField',
        'Get-JuribaDashboard',
        'Get-JuribaETLJob',
        'Get-JuribaEvergreenSelfService',
        'Get-JuribaEvergreenSelfServiceBaseURL',
        'Get-JuribaEvergreenSelfServiceComponent',
        'Get-JuribaEvergreenSelfServicePage',
        'Get-JuribaImportApplication',
        'Get-JuribaImportApplicationFeed',
        'Get-JuribaImportDepartmentFeed',
        'Get-JuribaImportDevice',
        'Get-JuribaImportDeviceFeed',
        'Get-JuribaImportLocation',
        'Get-JuribaImportLocationFeed',
        'Get-JuribaImportMailbox',
        'Get-JuribaImportMailboxFeed',
        'Get-JuribaImportUser',
        'Get-JuribaImportUserFeed',
        'Get-JuribaImportGroup',
        'Get-JuribaList',
        'Get-JuribaProject',
        'Get-JuribaProjectDetail',
        'Get-JuribaProjectPath',
        'Get-JuribaProjectReadiness',
        'Get-JuribaSessionUser',
        'Get-JuribaTag',
        'Get-JuribaTask',
        'Get-JuribaTeam',
        'Invoke-JuribaAutomation',
        'New-JuribaAutomation',
        'New-JuribaAutomationAction',
        'New-JuribaBucket',
        'New-JuribaCapacitySlot',
        'New-JuribaCapacityUnit',
        'New-JuribaCustomField',
        'New-JuribaDashboard',
        'New-JuribaDashboardBarWidget',
        'New-JuribaDashboardCardWidget',
        'New-JuribaDashboardColumnWidget',
        'New-JuribaDashboardDonutWidget',
        'New-JuribaDashboardHalfDonutWidget',
        'New-JuribaDashboardLineWidget',
        'New-JuribaDashboardListWidget',
        'New-JuribaDashboardPieWidget',
        'New-JuribaDashboardSection',
        'New-JuribaDashboardTableWidget',
        'New-JuribaEvergreenSelfService',
        'New-JuribaEvergreenSelfServiceComponent',
        'New-JuribaEvergreenSelfServicePage',
        'New-JuribaImportApplication',
        'New-JuribaImportApplicationFeed',
        'New-JuribaImportDepartmentFeed',
        'New-JuribaImportDevice',
        'New-JuribaImportDeviceFeed',
        'New-JuribaImportLocationFeed',
        'New-JuribaImportMailbox',
        'New-JuribaImportMailboxFeed',
        'New-JuribaImportUser',
        'New-JuribaImportUserFeed',
        'New-JuribaImportGroup',
        'New-JuribaList',
        'New-JuribaTag',
        'New-JuribaTeam',
        'Remove-JuribaAutomation',
        'Remove-JuribaBucket',
        'Remove-JuribaCapacitySlot',
        'Remove-JuribaCustomField',
        'Remove-JuribaDashboard',
        'Remove-JuribaEvergreenSelfServicePortal',
        'Remove-JuribaImportApplication',
        'Remove-JuribaImportDepartmentFeed',
        'Remove-JuribaImportDevice',
        'Remove-JuribaImportDeviceFeed',
        'Remove-JuribaImportLocationFeed',
        'Remove-JuribaImportMailbox',
        'Remove-JuribaImportMailboxFeed',
        'Remove-JuribaImportUserFeed',
        'Remove-JuribaImportGroup',
        'Remove-JuribaList',
        'Remove-JuribaTag',
        'Remove-JuribaTaskValueDate',
		    'Remove-JuribaTaskValueText',
        'Remove-JuribaTeam',
        'Set-JuribaAutomation',
        'Set-JuribaAutomationAction',
        'Set-JuribaBucket',
        'Set-JuribaCapacitySlot',
        'Set-JuribaDashboardSection',
        'Set-JuribaDashboardWidgetColour',
        'Set-JuribaEvergreenSelfService',
        'Set-JuribaEvergreenSelfServiceBaseURL',
        'Set-JuribaEvergreenSelfServiceComponent',
        'Set-JuribaEvergreenSelfServicePage',
        'Set-JuribaImportApplication',
        'Set-JuribaImportDevice',
        'Set-JuribaImportDeviceFeed',
        'Set-JuribaImportMailbox',
        'Set-JuribaImportMailboxFeed',
        'Set-JuribaImportUser',
        'Set-JuribaImportGroup',
        'Set-JuribaProjectCapacityDetail',
        'Set-JuribaTaskValueDate',
        'Set-JuribaTaskValueSelect',
        'Set-JuribaTaskValueText',
        'Set-JuribaTeam',
        'Start-JuribaETLJob',
        'Stop-JuribaETLJob',
        'Update-JuribaCustomFieldValue'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    # CmdletsToExport   = '*'

    # Variables to export from this module
    # VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    # AliasesToExport   = '*'

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            # Tags = @()

            # A URL to the license for this module.
            LicenseUri = 'https://raw.githubusercontent.com/juribalimited/powershell-module-platform/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/juribalimited/powershell-module-platform'

            # A URL to an icon representing this module.
            IconUri    = 'https://raw.githubusercontent.com/juribalimited/powershell-module-platform/main/resources/juriba_logo.jpeg'

            # ReleaseNotes of this module
            # ReleaseNotes = ''

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}
