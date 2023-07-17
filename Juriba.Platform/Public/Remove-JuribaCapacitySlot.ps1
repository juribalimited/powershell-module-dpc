function Remove-JuribaCapacitySlot {
    [alias("Remove-DwCapacitySlot")]
    <#
        .SYNOPSIS
        Delete the capacity slot in the project
        .DESCRIPTION
        Delete the capacity slot using API v1
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ProjectID
        ID of the project
        .PARAMETER SlotID
        ID/s of the capacity slot to delete
        .OUTPUTS
        The selected slot has been deleted
        .EXAMPLE
        PS> Remove-JuribaCapacitySlot @DwParams -ProjectID 1 -SlotID 1
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$ProjectID,
        [Parameter(Mandatory = $true)]
        [string]$SlotID
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    $contentType = "application/json"
    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = "{0}/apiv1/admin/projects/{1}/deleteCapacitySlots" -f $Instance, $ProjectID

    $payload = @{
        selectedObjectsList = $SlotID
    }

    $jsonbody = ($payload | ConvertTo-Json)

    try {
        $result = Invoke-WebRequest -Uri $uri -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -Method POST -ContentType $contentType
        return ($result.Content).Trim('"')
    }
    catch {
        Write-Error $_
    }
}