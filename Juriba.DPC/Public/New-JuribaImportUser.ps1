#Requires -Version 7
function New-JuribaImportUser {
    [alias("New-DwImportUser")]
    <#
        .SYNOPSIS
        Creates a new Juriba user using the import API. Provide a list of JSON objects in request payload to use bulk functionality (Max 1000 objects per request).

        .DESCRIPTION
        Creates a new Juriba user using the import API. Provide a list of JSON objects in request payload to use bulk functionality (Max 1000 objects per request).
        Takes the ImportId and JsonBody as an input.

        .PARAMETER Instance

        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ImportId

        ImportId for the user.

        .PARAMETER JsonBody

        Json payload with updated user details.

        .EXAMPLE
        PS> New-JuribaImportUser -ImportId 1 -JsonBody $jsonBody -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
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
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        # Retrieve Juriba product version
        $versionUri = "{0}/apiv1/" -f $Instance
        $versionResult = Invoke-WebRequest -Uri $versionUri -Method GET
        # Regular expression to match the version pattern
        $regex = [regex]"\d+\.\d+\.\d+"

        # Extract the version
        $version = $regex.Match($versionResult).Value
        $versionParts = $version -split '\.'
        $major = [int]$versionParts[0]
        $minor = [int]$versionParts[1]

        # Check if the version is 5.13 or older
        if ($major -lt 5 -or ($major -eq 5 -and $minor -le 13)) {
            $uri = "{0}/apiv2/imports/users/{1}/items" -f $Instance, $ImportId
            $bulkuri = "{0}/apiv2/imports/users/{1}/items/`$bulk" -f $Instance, $ImportId
        } else {
            $uri = "{0}/apiv2/imports/{1}/users" -f $Instance, $ImportId
            $bulkuri = "{0}/apiv2/imports/{1}/users/`$bulk" -f $Instance, $ImportId
        }
        $headers = @{'x-api-key' = $APIKey}
    
        try {
            if (($PSCmdlet.ShouldProcess(($JsonBody | ConvertFrom-Json).uniqueIdentifier)) -and (($JsonBody | ConvertFrom-Json).Length -eq 1)) {
                $result = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -ContentType "application/json" -Body ([System.Text.Encoding]::UTF8.GetBytes($JsonBody))
                return $result
            }
            elseif (($PSCmdlet.ShouldProcess(($JsonBody | ConvertFrom-Json).uniqueIdentifier)) -and (($JsonBody | ConvertFrom-Json).Length -gt 1)) {
                <# Bulk operation request #>
                $result = Invoke-RestMethod -Uri $bulkuri -Method POST -Headers $headers -ContentType "application/json" -Body ([System.Text.Encoding]::UTF8.GetBytes($JsonBody))
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
