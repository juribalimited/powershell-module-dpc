#requires -Version 7
function New-JuribaImportMailboxFeed {
    [alias("New-DwImportMailboxFeed")]
    <#
        .SYNOPSIS
        Creates a new mailbox feed.

        .DESCRIPTION
        Creates a new mailbox feed using the import API.

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER Name

        The name of the new mailbox feed.

        .PARAMETER Enabled

        Should the new feed be enabled. Default = True.

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

        .EXAMPLE

        PS> New-JuribaImportMailboxFeed -Name "My New Import" -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -SendOnBehalfPermissions 5 -MailboxPermissions 2 -MailboxExtendedRights 5

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [string]$Name,
        [parameter(Mandatory=$false)]
        [bool]$Enabled = $true,
        [parameter(Mandatory=$false)]
        [bool]$VerboseLogging = $true,
        [parameter(Mandatory=$false)]
        [bool]$ImportEntireForest = $false,
        [parameter(Mandatory=$true)]
        [int]$SendOnBehalfPermissions,
        [parameter(Mandatory=$true)]
        [int]$MailboxPermissions,
        [parameter(Mandatory=$true)]
        [int]$MailboxExtendedRights
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
            $uri = "{0}/apiv2/imports/mailboxes" -f $Instance
        } else {
            $uri = "{0}/apiv2/imports" -f $Instance
        }
        $headers = @{'x-api-key' = $APIKey}
    
        $payload = @{}
        $payload.Add("name", $Name)
        $payload.Add("enabled", $Enabled)
        $payload.Add("verboseLogging", $VerboseLogging)
        $payload.Add("importEntireForest", $ImportEntireForest)
        $payload.Add("sendOnBehalfPermissions", $SendOnBehalfPermissions)
        $payload.Add("mailboxPermissions", $MailboxPermissions)
        $payload.Add("mailboxExtendedRights", $MailboxExtendedRights)
    
        $JsonBody = $payload | ConvertTo-Json
    
        try {
            if ($PSCmdlet.ShouldProcess($Name)) {
                $result = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -ContentType "application/json" -Body $jsonBody
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