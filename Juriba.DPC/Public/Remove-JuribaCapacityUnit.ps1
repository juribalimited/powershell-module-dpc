function Remove-JuribaCapacityUnit {
    [alias("Remove-DwCapacityUnit")]
    <#
        .SYNOPSIS
        Delete the capacity unit in the project
        .DESCRIPTION
        Delete the capacity unit using API v1
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER UnitID
        ID/s of the capacity unit to delete
        .OUTPUTS
        The selected unit has been deleted
        .EXAMPLE
        PS> Remove-JuribaCapacityUnit @DwParams -UnitID 1
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [string]$UnitID
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    $contentType = "application/json"
    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = "{0}/apiv1/admin/capacityUnits/deleteCapacityUnits" -f $Instance

    $payload = @{
        selectedObjectsList = $UnitID
    }

    $jsonbody = ($payload | ConvertTo-Json)

    try {
        if($PSCmdlet.ShouldProcess($UnitID)) {
            $result = Invoke-WebRequest -Uri $uri -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -Method PUT -ContentType $contentType
            return ($result.Content).Trim('"')
        }
    }
    catch {
        Write-Error $_
    }
}