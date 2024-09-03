function Remove-JuribaBucket {
    [alias("Remove-DwBucket")]
    <#
        .SYNOPSIS
        Delete the bucket in the project
        .DESCRIPTION
        Delete the bucket using API v1
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ProjectID
        ID of the project
        .PARAMETER BucketID
        ID/s of the bucket to delete
        .OUTPUTS
        The selected buckets have been deleted
        .EXAMPLE
        PS> Remove-JuribaBucket @DwParams -ProjectID 1 -BucketID "1,2"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$ProjectID,
        [Parameter(Mandatory = $true)]
        [string]$BucketID
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    $contentType = "application/json"
    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = "{0}/apiv1/admin/projects/{1}/delete-buckets" -f $Instance, $ProjectID

    $payload = @{
        "selectedBucketsList" = $BucketID
    }

    $jsonbody = ($payload | ConvertTo-Json)

    try {
        if($PSCmdlet.ShouldProcess($BucketID)) {
            $result = Invoke-WebRequest -Uri $uri -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -Method DELETE -ContentType $contentType
            return ($result.Content).Trim('"')
        }
    }
    catch {
        Write-Error $_
    }
}