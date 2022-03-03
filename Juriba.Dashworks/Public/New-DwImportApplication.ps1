#Requires -Version 7
function New-DwImportApplication {
    <#
        .SYNOPSIS
        Creates a new Dashworks application using the import API.

        .DESCRIPTION
        Creates a new Dashworks application using the import API.
        Takes the ImportId and JsonBody as an input.

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app

        .PARAMETER Port

        Dashworks API port number. Default = 8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER ImportId

        ImportId for the application.

        .PARAMETER JsonBody

        Json payload with updated application details.

        .EXAMPLE
        PS> New-DwImportApplication -ImportId 1 -JsonBody $jsonBody -Instance "myinstance.dashworks.app" -APIKey "xxxxx"
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [int]$Port = 8443,
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

    $uri = "https://{0}:{1}/apiv2/imports/applications/{2}/items" -f $Instance, $Port, $ImportId
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