#requires -Version 7
function Remove-DwImportLocationFeed {
    <#
        .SYNOPSIS
        Deletes a location feed.

        .DESCRIPTION
        Deletes a location feed.
        Takes Id of feed to be deleted.

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app

        .PARAMETER Port

        Dashworks API port number. Default = 8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER ImportId

        The Id of the location feed to be deleted.

        .EXAMPLE

        PS> Remove-DwImportLocationFeed -ImportId 1 -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

        .EXAMPLE

        PS> Remove-DwImportLocationFeed -Confirm:$false -ImportId 1 -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

    #>
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [int]$ImportId
    )

    $uri = "{0}/apiv2/imports/locations/{1}" -f $Instance, $ImportId
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
}