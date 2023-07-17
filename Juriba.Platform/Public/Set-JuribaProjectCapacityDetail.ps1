function Set-JuribaProjectCapacityDetail {
    [alias("Set-DwProjectCapacityDetail")]
    <#
        .SYNOPSIS
        Update the project capacity detail
        .DESCRIPTION
        Update the project capacity detail using API v1
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ProjectID
        ID of the project
        .PARAMETER CapacityMode
        The capacity mode to be used, either Teams & Request Types, Capacity Units
        .PARAMETER CapacityUnitMode
        The capacity unit mode to be used, Project Capacity Units, Evergreen Capacity Units, Clone Evergreen Capacity Units, CapacityUnits
        .PARAMETER CapacityToReachBeforeShowAmber
        Integer to define the capacity to reach before showing amber
        .PARAMETER EnableCapacity
        Boolean flag to set if using capacity
        .PARAMETER EnforceCapacityOnProjectObject
        Boolean flag to set if enforce capacity on project object
        .PARAMETER EnforceCapacityOnSelfService
        Boolean flag to set if enforce capacity on self service
        .OUTPUTS
        The project capacity details have been updated
        .EXAMPLE
        PS> Set-JuribaProjectCapacityDetail @DwParams -CapacityMode "Capacity Units" -CapacityUnitMode "Project Capacity Units" 
            -CapacityToReachBeforeShowAmber 90 -EnableCapacity $true -EnforceCapacityOnProjectObject $false -EnforceCapacityOnSelfService $true
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$ProjectID,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Teams & Request Types","Capacity Units")]
        [string]$CapacityMode,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Project Capacity Units","Evergreen Capacity Units","Clone Evergreen Capacity Units")]
        [string]$CapacityUnitMode,
        [Parameter(Mandatory=$true)]
        [int]$CapacityToReachBeforeShowAmber,
        [Parameter(Mandatory=$true)]
        [bool]$EnableCapacity,
        [Parameter(Mandatory=$true)]
        [bool]$EnforceCapacityOnProjectObject,
        [Parameter(Mandatory=$true)]
        [bool]$EnforceCapacityOnSelfService
    )

    $CapacityModeId = switch ($CapacityMode) {
        "Teams & Request Types"  { 1 }
        "Capacity Units" { 2 }
    }

    $CapacityUnitModeId = switch ($CapacityUnitMode) {
        "Project Capacity Units"  { 1 }
        "Evergreen Capacity Units" { 2 }
        "Clone Evergreen Capacity Units" { 3 }
    }

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    $jsonbody = (@{
        "capacityModeId" = $CapacityModeId
        "capacityUnitModeId" = $CapacityUnitModeId
        "capacityToReachBeforeShowAmber" = $CapacityToReachBeforeShowAmber
        "enableCapacity" = $EnableCapacity
        "enforceCapacityOnProjectObject" = $EnforceCapacityOnProjectObject
        "enforceCapacityOnSelfService" = $EnforceCapacityOnSelfService
    }) | ConvertTo-Json

    $contentType = "application/json"
    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = "{0}/apiv1/admin/projects/{1}/updateProjectCapacityDetails" -f $Instance, $ProjectID

    try {
        $result = Invoke-WebRequest -Uri $uri -Method PUT -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType $contentType
        return ($result.Content).Trim('"')
    }
    catch {
        Write-Error $_
    }
}