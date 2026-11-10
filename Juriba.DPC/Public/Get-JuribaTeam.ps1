function Get-JuribaTeam {
    <#
        .SYNOPSIS
        Returns all teams
        .DESCRIPTION
        Returns all teams using API v1
        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .OUTPUTS
        Team objects
        teamID, teamName, description, members, evergreenGroups, projectGroups, isDefault, defaultColumn
        .EXAMPLE
        PS> Get-JuribaTeam -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx"
    #>
    [alias("Get-DwTeam")]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = ("{0}/apiv1/admin/team/teams" -f $Instance) + '?$lang=en-US'

    try {
        $result = Invoke-WebRequest -Uri $uri -Headers $headers -Method GET
        return ($result.Content | ConvertFrom-Json).results
    }
    catch {
        Write-Error $_
    }
}