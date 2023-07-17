function Remove-JuribaTeam {
    [alias("Remove-DwTeam")]
    <#
        .SYNOPSIS
        Delete the teams
        .DESCRIPTION
        Delete the teams using API v1
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ReassignedTeamID
        TeamID to reassigned to upon deletion
        .PARAMETER TeamID
        ID/s of the team to delete
        .OUTPUTS
        The selected team has been deleted, and their buckets reassigned
        .EXAMPLE
        PS> Remove-JuribaTeam @DwParams -ReassignedTeamID 5 -TeamID 1
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory=$false)]
        [int]$ReassignedTeamID=$null,
        [Parameter(Mandatory=$true)]
        [string]$TeamID
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = "{0}/apiv1/admin/team/deleteTeams" -f $Instance

    $payload = @{
        "selectedObjectsList" = $TeamID
        "objectId" = if($null -eq $ReassignedTeamID -or $ReassignedTeamID -eq 0) { $null } else { $ReassignedTeamID }
    }

    $jsonbody = ($payload | ConvertTo-Json)

    try {
        $result = Invoke-WebRequest -Uri $uri -Headers $headers -Body $jsonbody -Method PUT -ContentType $contentType
        return ($result.Content).Trim('"')
    }
    catch {
        Write-Error $_
    }
}