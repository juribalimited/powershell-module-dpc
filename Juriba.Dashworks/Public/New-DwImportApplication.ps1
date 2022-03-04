#Requires -Version 7
function New-DwImportApplication {
    <#
        .SYNOPSIS
        Creates a new Dashworks application using the import API.

        .DESCRIPTION
        Creates a new Dashworks application using the import API.
        Takes the ImportId and JsonBody as an input.

        .PARAMETER Instance

        Dashworks instance. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER ImportId

        ImportId for the application.

        .PARAMETER JsonBody

        Json payload with updated application details.

        .EXAMPLE
        PS> New-DwImportApplication -ImportId 1 -JsonBody $jsonBody -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"
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
            ((Test-Json $_) -and (($_ | ConvertFrom-Json).uniqueIdentifier))
        },
        ErrorMessage = "JsonBody is not valid json or does not contain a uniqueIdentifier"
        )]
        [parameter(Mandatory=$true)]
        [string]$JsonBody
    )

    $uri = "{0}/apiv2/imports/applications/{1}/items" -f $Instance, $ImportId
    $headers = @{'x-api-key' = $APIKey}

    try {
        if ($PSCmdlet.ShouldProcess(($JsonBody | ConvertFrom-Json).uniqueIdentifier)) {
            $result = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -ContentType "application/json" -Body $jsonBody
            return $result
        }
    }
    catch {
        Write-Error $_
    }

}