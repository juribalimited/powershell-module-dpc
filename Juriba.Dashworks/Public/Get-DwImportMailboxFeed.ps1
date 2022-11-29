#requires -Version 7
function Get-DwImportMailboxFeed {
    <#
        .SYNOPSIS
        Gets mailbox imports.

        .DESCRIPTION
        Gets one or more mailbox feeds.
        Use ImportId to get a specific feed or omit for all feeds.

        .PARAMETER Instance

        Dashworks instance. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER ImportId

        Optional. The id for the mailbox feed. Omit to get all mailbox feeds.

        .PARAMETER Name

        Optional. Name of mailbox feed to find. Can only be used when ImportId is not specified.

        .EXAMPLE

        PS> Get-DwImportMailboxFeed -ImportId 1 -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

        .EXAMPLE

        PS> Get-DwImportMailboxFeed -Name "My Mailbox Feed" -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [parameter(Mandatory=$false)]
        [int]$ImportId,
        [parameter(Mandatory=$false)]
        [string]$Name
    )

    $uri = "{0}/apiv2/imports/mailboxes" -f $Instance

    if ($ImportId) {$uri += "/{0}" -f $ImportId}
    if ($Name) {
        $uri += "?filter="
        $uri += [System.Web.HttpUtility]::UrlEncode("eq(name,'{0}')" -f $Name)
    }

    $headers = @{'x-api-key' = $APIKey}

    try {
        $result = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
        return $result
    }
    catch {
        Write-Error $_
    }

}