#requires -Version 7
function Remove-DwImportDepartmentFeed {
    <#
        .SYNOPSIS
        Deletes a department feed.

        .DESCRIPTION
        Deletes a department feed.
        Takes Id of feed to be deleted.

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app

        .PARAMETER Port

        Dashworks API port number. Default = 8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER ImportId

        The Id of the department feed to be deleted.

        .EXAMPLE

        PS> Remove-DwImportDepartmentFeed -ImportId 1 -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

        .EXAMPLE

        PS> Remove-DwImportDepartmentFeed -Confirm:$false -ImportId 1 -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

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

    $uri = "{0}/apiv2/imports/departments/{1}" -f $Instance, $ImportId
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