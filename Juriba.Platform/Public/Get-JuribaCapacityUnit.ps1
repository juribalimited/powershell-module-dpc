function Get-JuribaCapacityUnit {
    [alias("Get-DwCapacityUnit")]
    <#
        .SYNOPSIS
        Returns capacity units for a specified project or evergreen.
        .DESCRIPTION
        Returns capacity units as an array.
        Takes ProjectID as an input - returns for project if provided or 
        for evegreen AND project if not provided.
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ProjectID
        ProjectID of the Project to get Tasks for.
        .OUTPUTS
        Capacity unit objects
        unitId, projectId, unitName, unitDescription, isDefault, sourceUnitId, capacityUnits1, capacityUnit1, projectObjects, capacitySlots, devices, users, mailboxes, applications, projectName, isDefaultColumn, slotsCount, sourceEvergreenUnitName, sourceEvergreenUnitId, objectKey, evergreenObjectId
        .EXAMPLE
        PS> Get-JuribaCapacityUnit @dwparams -ProjectID 1
    #>   
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [int]$ProjectID
    )
    if ($ProjectID) {
		$uri = ("{0}/apiv1/admin/capacityUnits/{1}/projectCapacityUnits" -f $Instance, $ProjectID) + '?$lang=en-US'
		$headers = @{
            'x-api-key' = $APIKey
            'cache-control' = 'no-cache'
		}
        try {
            $result = Invoke-WebRequest -Uri $Uri -Method GET -Headers $headers
            return ($result.content | ConvertFrom-Json).results
        }
		Catch {
			Write-Error $_
		}
    }
    else {
        $uri = ("{0}/apiv1/admin/capacityUnits/list" -f $Instance) + '?$lang=en-US'
        $headers = @{
            'x-api-key' = $APIKey
            'cache-control' = 'no-cache'
		}
        try {
            $result = Invoke-WebRequest -Uri $Uri -Method GET -Headers $headers -ContentType "application/json" 
            return ($result.content | ConvertFrom-Json).results
        }
		Catch {
			Write-Error $_
		}
    }
}