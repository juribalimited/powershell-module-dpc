function New-JuribaTeam {
    <#
        .SYNOPSIS
        Create new team
        .DESCRIPTION
        Create new team using API v1
        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER TeamName
        Name of the team
        .PARAMETER Description
        Description of the team
        .PARAMETER IsDefault
        Boolean flag to set if the team is default
        .OUTPUTS
        teamId
        .EXAMPLE
        PS> New-JuribaTeam -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -TeamName "A Team" -Description "A new team"
    #>
    [alias("New-DwTeam")]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory=$true)]
        [string]$TeamName,
        [Parameter(Mandatory=$true)]
        [string]$Description,
        [Parameter(Mandatory=$false)]
        [bool]$IsDefault=$false
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    $jsonbody = (@{
        "teamName" = $TeamName
        "description" = $Description
        "isDefault" = $IsDefault
    }) | ConvertTo-Json

    $contentType = "application/json"
    $headers = @{ 'X-API-KEY' = $ApiKey }
    $uri = "{0}/apiv1/admin/team/createTeam" -f $Instance

    try {
        if($PSCmdlet.ShouldProcess($TeamName)) {
            $result = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType $contentType
            return ($result.Content | ConvertFrom-Json).teamId
        }
    }
    catch {
        Write-Error $_
    }
}