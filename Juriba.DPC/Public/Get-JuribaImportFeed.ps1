#requires -Version 7
function Get-JuribaImportFeed {
    <#
        .SYNOPSIS
        Gets universal imports.

        .DESCRIPTION
        Gets one or more universal feeds.
        Use ImportId to get a specific feed or omit for all feeds.

        .PARAMETER ImportId

        Optional. The id for the universal feed. Omit to get all universal feeds.

        .PARAMETER Name

        Optional. Name of universal feed to find. Can only be used when ImportId is not specified.

        .PARAMETER Instance

        Optional. DPC instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .EXAMPLE

        PS> Get-JuribaImportFeed -ImportId 1

        .EXAMPLE

        PS> Get-JuribaImportFeed -Name "My Universal Feed"

    #>
    [CmdletBinding(DefaultParameterSetName="Name")]
    param (
        [parameter(Mandatory=$false)]
        [int]$ImportId,
        [parameter(Mandatory=$false)]
        [string]$Name,
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        try {
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
                throw "This function is only supported on Juriba DPC 5.14 and later."
            } else {
                $uri = "{0}/apiv2/imports" -f $Instance
            }
            if ($ImportId) {$uri += "/{0}" -f $ImportId}
            if ($Name) {
                $uri += "?filter="
                $uri += [System.Web.HttpUtility]::UrlEncode("eq(name,'{0}')" -f $Name)
            }
            $headers = @{'x-api-key' = $APIKey}
            $result = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
            return $result
        }
        catch {
            Write-Error $_
        }  
    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}