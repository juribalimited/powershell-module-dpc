function Get-JuribaBucket {
    [alias("Get-DwBucket")]
    <#
        .SYNOPSIS
        Returns all buckets in US English.
        .DESCRIPTION
        Returns all buckets using API v1
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ProjectID
        ID of the project
        .OUTPUTS
        Bucket objects
        groupId, groupName, groupTypeID, groupType, teamName, ownerTeamID, default, defaultColumn, devices, users, mailboxes, projectName, projectId, sourceEvergreenGroupName, isMyTeamBucket
        .EXAMPLE
        PS> Get-JuribaBucket @DwParams -ProjectID 1
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
    $uri = ("{0}/apiv1/admin/projects/{1}/bucket-lists" -f $Instance, $ProjectID) + '?$lang=en-US'

    try {
        $result = Invoke-WebRequest -Uri $uri -Headers $headers -Method GET
        return ($result.Content | ConvertFrom-Json).results
    }
    catch {
        Write-Error $_
    }
}