function New-JuribaBucket {
    [alias("New-DwBucket")]
    <#
        .SYNOPSIS
        Create a new bucket in US English.
        .DESCRIPTION
        Create a new bucket using API v1
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ProjectID
        ID of the project
        .PARAMETER BucketName
        Name of the bucket
        .PARAMETER OwnerTeamID
        ID of the team assigned
        .PARAMETER Default
        Boolean value to flag if this item is default or not
        .OUTPUTS
        bucketId
        .EXAMPLE
        PS> New-JuribaBucket @DwParams -ProjectID 1 -BucketName "01 Preview" -OwnerTeamID 1
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$ProjectID,
        [Parameter(Mandatory=$true)]
        [string]$BucketName,
        [Parameter(Mandatory = $true)]
        [int]$OwnerTeamID,
        [Parameter(Mandatory = $false)]
        [bool]$Default=$false
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    $jsonbody = (@{
        "bucketName" = $BucketName
        "ownerTeamId" = $OwnerTeamID
        "default" = $Default
    }) | ConvertTo-Json

    $contentType = "application/json"
    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = "{0}/apiv1/admin/projects/{1}/create-bucket" -f $Instance, $ProjectID

    try {
        $result = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType $contentType
        return ($result.Content | ConvertFrom-Json).bucketId
    }
    catch {
        Write-Error $_
    }
}