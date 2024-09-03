#requires -Version 7
function Remove-JuribaImportApplicationFeed {
    [alias("Remove-DwImportApplicationFeed")]
    <#
        .SYNOPSIS
        Deletes an application feed.

        .DESCRIPTION
        Deletes an application feed.
        Takes Id of feed to be deleted.

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER Port

        Dashworks API port number. Default = 8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ImportId

        The Id of the application feed to be deleted.

        .EXAMPLE

        PS> Remove-JuribaImportApplicationFeed -ImportId 1 -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

        .EXAMPLE

        PS> Remove-JuribaImportApplicationFeed -Confirm:$false -ImportId 1 -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

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
        $uri = "{0}/apiv2/imports/applications/{1}" -f $Instance, $ImportId
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