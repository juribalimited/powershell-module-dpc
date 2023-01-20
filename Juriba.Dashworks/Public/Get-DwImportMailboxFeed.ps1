#requires -Version 7
function Get-DwImportMailboxFeedV2 {
    <#
        .SYNOPSIS
        Gets mailbox imports.

        .DESCRIPTION
        Gets one or more mailbox feeds.
        Use ImportId to get a specific feed or omit for all feeds.

        .PARAMETER ImportId

        Optional. The id for the mailbox feed. Omit to get all mailbox feeds.

        .PARAMETER Name

        Optional. Name of mailbox feed to find. Can only be used when ImportId is not specified.

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .EXAMPLE

        PS> Get-DwImportMailboxFeed -ImportId 1

        .EXAMPLE

        PS> Get-DwImportMailboxFeed -Name "My Mailbox Feed"

    #>
    [CmdletBinding()]
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
            $uri = "{0}/apiv2/imports/mailboxes" -f $Instance
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