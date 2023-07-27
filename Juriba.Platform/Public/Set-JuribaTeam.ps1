function Set-JuribaTeam {
    [alias("Set-DwTeam")]
    <#
        .SYNOPSIS
        Update the team
        .DESCRIPTION
        Update the team using API v1
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER TeamID
        ID of the team
        .PARAMETER TeamName
        Name of the team
        .PARAMETER Description
        Description of the team
        .PARAMETER IsDefault
        Boolean flag to set if the team is default
        .OUTPUTS
        The team was successfully updated
        .EXAMPLE
        PS> Set-JuribaTeam @DwParams -TeamID 1 -TeamName "A Team" -Description "A new team"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory=$true)]
        [int]$TeamID,
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
    $uri = "{0}/apiv1/admin/team/{1}/updateTeam" -f $Instance, $TeamID

    try {
        if($PSCmdlet.ShouldProcess($TeamID)) {
            $result = Invoke-WebRequest -Uri $uri -Method PUT -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType $contentType
            return ($result.Content | ConvertFrom-Json).message
        }
    }
    catch {
        Write-Error $_
    }
}