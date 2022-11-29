#requires -Version 7
function Set-DwImportMailboxFeed {
    <#
        .SYNOPSIS
        Updates a mailbox feed.

        .DESCRIPTION
        Updates a mailbox feed using the import API.
        Takes the new name and/or enabled status.

        .PARAMETER Instance

        Dashworks instance. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER ImportId

        Id of feed to be updated.

        .PARAMETER Name

        The name of the new mailbox feed.

        .PARAMETER VerboseLogging

        Enable verbose logging for the mailbox import. Default = True.

        .PARAMETER ImportEntireForest

        Specify whether to import the whole directory forest. Default = False.

        .PARAMETER SendOnBehalfPermissions

        Process Send On Behalf Permissions. The following values are allowed: 1 (No), 2 (Using AD Data), 5 (Using Mailbox Data).

        .PARAMETER MailboxPermissions

        Process Mailbox Permissions. The following values are allowed: 1 (No), 2 (Using AD Data), 5 (Using Mailbox Data).

        .PARAMETER MailboxExtendedRights

        Process Mailbox Extended Rights. The following values are allowed: 1 (No), 2 (Using AD Data), 5 (Using Mailbox Data).

        .PARAMETER Enabled

        Should the new feed be enabled.

        .EXAMPLE

        PS> Set-DwImportMailboxFeed -ImportId 1 -Name "My New Import Name" -Enabled $false -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [int]$ImportId,
        [parameter(Mandatory=$false)]
        [string]$Name,
        [parameter(Mandatory=$false)]
        [bool]$VerboseLogging,
        [parameter(Mandatory=$false)]
        [bool]$ImportEntireForest,
        [parameter(Mandatory=$false)]
        [int]$SendOnBehalfPermissions,
        [parameter(Mandatory=$false)]
        [int]$MailboxPermissions,
        [parameter(Mandatory=$false)]
        [int]$MailboxExtendedRights,
        [parameter(ParameterSetName = 'FeedEnabled', Mandatory = $false)]
        [bool]$Enabled
    )

    if (-Not $Name -And -Not $PSCmdlet.ParameterSetName -eq 'FeedEnabled') {
        throw "Either Name or Enabled must be specified."
    }

    $uri = "{0}/apiv2/imports/mailboxes/{1}" -f $Instance, $ImportId
    $headers = @{'x-api-key' = $APIKey}

    $payload = @{}
    if ($name) {
        $payload.Add("name", $Name)
        if ($VerboseLogging) {$payload.Add("verboseLogging", $VerboseLogging)}
        if ($ImportEntireForest) {$payload.Add("importEntireForest", $ImportEntireForest)}
        if ($SendOnBehalfPermissions) {$payload.Add("sendOnBehalfPermissions", $SendOnBehalfPermissions)}
        if ($MailboxPermissions) {$payload.Add("mailboxPermissions", $MailboxPermissions)}
        if ($MailboxExtendedRights) {$payload.Add("mailboxExtendedRights", $MailboxExtendedRights)}
    }
    if ($PSCmdlet.ParameterSetName -eq 'FeedEnabled') { $payload.Add("enabled", $Enabled) }

    $jsonBody = $payload | ConvertTo-Json

    try {
        if ($PSCmdlet.ShouldProcess($ImportId)) {
            $result = Invoke-RestMethod -Uri $uri -Method PATCH -Headers $headers -ContentType "application/json" -Body $jsonBody
            return $result
        }
    }
    catch {
        if ($_.Exception.Response.StatusCode.Value__ -eq 409)
        {
            Write-Error ("{0}" -f "Update conflicted with another feed. Check if another feed exists with the same name.")
        }
        else {
            Write-Error $_
        }
    }
}