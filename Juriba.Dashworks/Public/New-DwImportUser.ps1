#Requires -Version 7
function New-DwImportUser {
    <#
        .SYNOPSIS
        Creates a new Dashworks user using the import API.

        .DESCRIPTION
        Creates a new Dashworks user using the import API.
        Takes the ImportId and JsonBody as an input.

        .PARAMETER Instance

        Dashworks instance. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER ImportId

        ImportId for the user.

        .PARAMETER JsonBody

        Json payload with updated user details.

        .EXAMPLE
        PS> New-DwImportUser -ImportId 1 -JsonBody $jsonBody -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [int]$ImportId,
        [ValidateScript({
            ((Test-Json $_) -and (($_ | ConvertFrom-Json).username))
        },
        ErrorMessage = "JsonBody is not valid json or does not contain a username"
        )]
        [parameter(Mandatory=$true)]
        [string]$JsonBody
    )

    $uri = "{0}/apiv2/imports/users/{1}/items" -f $Instance, $ImportId
    $headers = @{'x-api-key' = $APIKey}

    try {
        if ($PSCmdlet.ShouldProcess(($JsonBody | ConvertFrom-Json).username)) {
            $result = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -ContentType "application/json" -Body $jsonBody
            return $result
        }
    }
    catch {
        Write-Error $_
    }

}