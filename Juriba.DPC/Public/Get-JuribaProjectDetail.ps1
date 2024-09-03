function Get-JuribaProjectDetail {
    [alias("Get-DwProjectDetail")]
    <#
        .SYNOPSIS
        Returns all project details
        .DESCRIPTION
        Returns all project details using API v1
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ProjectID
        ID of the project
        .OUTPUTS
        Project details object
        name, shortName, description, bucketModeId, ringModeId, capacityUnitModeId, showOriginalApplicationColumnOnApplicationDashboard, languageId, projectTypeId, capacityModeId, enableCapacity, enforceCapacityOnSelfService, enforceCapacityOnProjectObject, capacityToReachBeforeShowAmber, translations, isEvergreenProject, createdObjectsCount, languages, projectType
        .EXAMPLE
        PS> Get-JuribaProjectDetail @DwParams -ProjectID 1
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$ProjectID
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = "{0}/apiv1/admin/projects/{1}/projectDetails" -f $Instance, $ProjectID

    try {
        $result = Invoke-WebRequest -Uri $uri -Headers $headers -Method GET
        return ($result.Content | ConvertFrom-Json)
    }
    catch {
        Write-Error $_
    }
}