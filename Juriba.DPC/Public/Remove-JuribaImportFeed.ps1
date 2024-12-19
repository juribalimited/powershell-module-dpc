#requires -Version 7
function Remove-JuribaImportFeed {
    <#
        .SYNOPSIS
        Deletes a universal feed.

        .DESCRIPTION
        Deletes a universal feed.
        Takes Id of feed to be deleted.

        .PARAMETER Instance

        Optional. DPC instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER Port

        DPC API port number. Default = 8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ImportId

        The Id of the universal feed to be deleted.

        .EXAMPLE

        PS> Remove-JuribaImportFeed -ImportId 1 -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

        .EXAMPLE

        PS> Remove-JuribaImportFeed -Confirm:$false -ImportId 1 -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

    #>
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [int]$ImportId
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
            throw "This function is only supported on Juriba DPC 5.14 and later."
        } else {
            $uri = "{0}/apiv2/imports/{1}" -f $Instance, $ImportId
        }
        $headers = @{'x-api-key' = $APIKey}
    
        try {
            if ($PSCmdlet.ShouldProcess($ImportId)) {
                $result = Invoke-RestMethod -Uri $uri -Method DELETE -Headers $headers
                return $result
            }
        }
        catch {
            Write-Error $_
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}