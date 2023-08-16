function Get-JuribaProject {
    [alias("Get-DwProject")]
    <#
        .SYNOPSIS
        Returns all projects in US English.
        .DESCRIPTION
        Returns all project details as an array.
        Takes no inputs except authentication
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .OUTPUTS
        Project objects
        projectName, shortName, active, projectType, projectTypeId, userScopeName, mailboxScopeName, deviceScopeName, applicationScopeName, isEmpty, isEvergreenProject, isEvergreenProjectColumn, objectTypeName, projectId, primaryObjectTypeId, includeDevices, deviceScopeListId, includeUsers, userScopeListId, includeApplications, applicationScopeListId, applicationAssociationDeviceOwnerScopeListId, applicationAssociationOwnedDeviceScopeListId, includeMailboxes, mailboxScopeListId, mailboxAssociationDeviceOwnerScopeListId, includeAppsInstalledOnDevice, includeAppsEntitledToDevice, includeAppsEntitledToUser, includeAppsUsedOnDeviceByAnyUser, includeAppsUsedOnDeviceByDeviceOwner, includeAppsUsedByUserOnAnyDevice, includeMailboxesOwnedByUser, includeMailboxesDelegatedToUser, includeMailboxOwner, includeMailboxDelegates, capacityUnitOnboardActionId, capacityUnitOnboardActionOverridable, autoOnboardScheduleTypeId, autoOnboardDevices, autoOffboardDevices, autoOnboardUsers, autoOffboardUsers, autoOnboardApplications, autoOffboardApplications, autoOnboardMailboxes, autoOffboardMailboxes, includeApplicationOwners, applicationOwnerScopeListId, applicationOwnerRequestTypeId, includeMailboxPermissionUsers, includeFolderPermissionUsers, autoOnboardSQLAgentJobName, evergreenProjectMailboxPermissions, objectType, capacityUnitOnboardAction, project
        .EXAMPLE
        PS> Get-JuribaProject @DwParams
    #>   
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey
    )
	
	$uri = ("{0}/apiv1/admin/projects/allProjects" -f $Instance) + '?$lang=en-US'
    $headers = @{
        'x-api-key' = $APIKey
        'cache-control' = 'no-cache'
    }
    try {
        $result = Invoke-WebRequest -Uri $Uri -Method GET -Headers $headers -ContentType "application/json"
        return ($result.content | ConvertFrom-Json).results
    }
    Catch 
    {
        Write-Error $_
    }
}