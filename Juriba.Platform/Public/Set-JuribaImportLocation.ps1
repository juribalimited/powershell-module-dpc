#Requires -Version 7
function Set-JuribaImportLocation {
    [alias("Set-DwImportLocation")]
    <#
        .SYNOPSIS
        Updates a location in the import API. Provide a list of JSON objects in request payload to use bulk functionality (Max 1000 objects per request).

        .DESCRIPTION
        Updates a location in the import API. Provide a list of JSON objects in request payload to use bulk functionality (Max 1000 objects per request).
        Takes the ImportId, UniqueIdentifier and jsonBody as an input.

        .PARAMETER Instance

        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER UniqueIdentifier

        Optional. UniqueIdentifier for the location. Optional only when submitting a bulk request (UniqueIdentifier to be provided in payload instead)

        .PARAMETER ImportId

        ImportId for the location.

        .PARAMETER JsonBody

        Json payload with updated location details.

        .EXAMPLE
        PS> Set-JuribaImportLocation -ImportId 1 -Name "w123abc" -JsonBody $jsonBody -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$false)]
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
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $uri = "{0}/apiv2/imports/locations/{1}/items/{2}" -f $Instance, $ImportId, $UniqueIdentifier
        $bulkuri = "{0}/apiv2/imports/locations/{1}/items/`$bulk" -f $Instance, $ImportId
        $headers = @{'x-api-key' = $APIKey}
    
        try {
            if (($PSCmdlet.ShouldProcess($UniqueIdentifier)) -and (($JsonBody | ConvertFrom-Json).Length -eq 1)) {
                $result = Invoke-WebRequest -Uri $uri -Method PATCH -Headers $headers -ContentType "application/json" -Body [System.Text.Encoding]::UTF8.GetBytes($JsonBody)
                return $result
            }
            elseif (($PSCmdlet.ShouldProcess(($JsonBody | ConvertFrom-Json).uniqueIdentifier)) -and (($JsonBody | ConvertFrom-Json).Length -gt 1)) {
                <# Bulk operation request #>
                $result = Invoke-RestMethod -Uri $bulkuri -Method PATCH -Headers $headers -ContentType "application/json" -Body [System.Text.Encoding]::UTF8.GetBytes($JsonBody)
                return $result
            }
        }
        catch {
            Write-Error $_
        }

    }
    else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
