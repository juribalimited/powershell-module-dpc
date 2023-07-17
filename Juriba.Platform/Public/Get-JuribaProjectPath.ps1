function Get-JuribaProjectPath {
    [alias("Get-DwProjectPath")]
    <#
        .SYNOPSIS
        Returns Paths/Request Types for a specified project.
        .DESCRIPTION
        Returns Paths/Request Types as an array.
        Takes ProjectID as an input
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ProjectID
        ProjectID of the Project to get paths for.
        .OUTPUTS
        Path/Request Type objects
        Keys:
        projectId, pathId, pathName, pathDescription, default, objectType, objectTypeId, objectTypeLower, taskCount, languageCount, objectCount
        .EXAMPLE
        PS> Get-JuribaProjectPath @DwParams -ProjectID 1
    #>
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [int]$ProjectID
    )
	$uri = "{0}/apiv1/admin/projects/{1}/paths" -f $Instance, $ProjectID
    $headers = @{
        'x-api-key' = $APIKey
        'cache-control' = 'no-cache'
    }
    try {
        $result = Invoke-WebRequest -Uri $Uri -Method GET -Headers $headers -ContentType "application/json"
        return ($result.content | ConvertFrom-Json)
    } Catch 
    {Write-Error $_}
}