function Set-JuribaBucket {
    [alias("Set-DwBucket")]
    <#
        .SYNOPSIS
        Update bucket.
        .DESCRIPTION
        Update bucket using API v1
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ProjectID
        ID of the project
        .PARAMETER BucketID
        ID of the bucket to update
        .PARAMETER BucketName
        Name of the bucket
        .PARAMETER OwnerTeamID
        ID of the team assigned
        .PARAMETER Default
        Boolean value to flag if this item is default or not
        .OUTPUTS
        The xxx bucket has been updated
        .EXAMPLE
        PS> Set-JuribaBucket @DwParams -ProjectID 1 -BucketID 9 -BucketName "01 Preview" -OwnerTeamID 1
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$ProjectID,
        [Parameter(Mandatory = $true)]
        [int]$BucketID,
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
        "bucketId" = $BucketID
        "bucketName" = $BucketName
        "ownerTeamId" = $OwnerTeamID
        "default" = $Default
    }) | ConvertTo-Json

    $contentType = "application/json"
    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = "{0}/apiv1/admin/projects/{1}/update-bucket" -f $Instance, $ProjectID

    try {
        $result = Invoke-WebRequest -Uri $uri -Method PUT -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType $contentType
        return ($result.Content | ConvertFrom-Json).message
    }
    catch {
        Write-Error $_
    }
}