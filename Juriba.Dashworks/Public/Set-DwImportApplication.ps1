#Requires -Version 7
function Set-DwImportApplication {
    <#
        .SYNOPSIS
        Updates a application in the import API.

        .DESCRIPTION
        Updates a application in the import API.
        Takes the ImportId, UniqueIdentifier and jsonBody as an input.

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app

        .PARAMETER Port

        Dashworks API port number. Default = 8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER UniqueIdentifier

        UniqueIdentifier for the application.

        .PARAMETER ImportId

        ImportId for the application.

        .PARAMETER JsonBody

        Json payload with updated application details.

        .EXAMPLE
        PS> Set-DwImportApplication -ImportId 1 -UniqueIdentifier "app123" -JsonBody $jsonBody -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

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
        [string]$UniqueIdentifier,
        [parameter(Mandatory=$true)]
        [int]$ImportId,
        [ValidateScript({
            Test-Json $_
        },
        ErrorMessage = "JsonBody is not valid json."
        )]
        [parameter(Mandatory=$true)]
        [string]$JsonBody
    )

    $uri = "https://{0}:{1}/apiv2/imports/applications/{2}/items/{3}" -f $Instance, $Port, $ImportId, $UniqueIdentifier
    $headers = @{'x-api-key' = $APIKey}

    try {
        if ($PSCmdlet.ShouldProcess($UniqueIdentifier)) {
            $result = Invoke-WebRequest -Uri $uri -Method PATCH -Headers $headers -ContentType "application/json" -Body $JsonBody
            return $result
        }
    }
    catch {
        Write-Error $_
    }

}