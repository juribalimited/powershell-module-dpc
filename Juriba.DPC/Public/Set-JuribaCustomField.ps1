#requires -Version 7
function Set-JuribaCustomField {
    <#
        .SYNOPSIS
        Updates the definition of an existing custom field.

        .DESCRIPTION
        Updates the definition of an existing custom field using the Juriba DPC API v1.
        Only the settings supplied are changed. All other settings are read from the current custom field and sent back unchanged.
        The value type of a custom field cannot be changed with this function, as existing values are not converted to the new type.

        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER CustomFieldId
        Id of the custom field to update.

        .PARAMETER Name
        Optional. New name for the custom field. Maximum 50 characters.

        .PARAMETER CSVColumnHeader
        Optional. New CSV column header for the custom field. Maximum 50 characters. Must not be used by another custom field.

        .PARAMETER ObjectTypes
        Optional. Object types that this custom field applies to. Replaces the current object types. One or more of Device, User, Application, Mailbox.

        .PARAMETER IsActive
        Optional. Set the custom field to active or inactive.

        .PARAMETER AllowUpdate
        Optional. Sets the type of updates allowed for this custom field. Either Directly or ETL.

        .PARAMETER AllowExternalUpdate
        Optional. Sets whether the custom field allows external updates.

        .OUTPUTS
        None.

        .EXAMPLE
        PS> Set-JuribaCustomField -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxx" -CustomFieldId 42 -ObjectTypes Device, User -IsActive $false

        .EXAMPLE
        PS> Set-JuribaCustomField -CustomFieldId 42 -Name "Warranty End Date" -AllowExternalUpdate $false
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory=$true)]
        [int]$CustomFieldId,
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 50)]
        [string]$Name,
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 50)]
        [string]$CSVColumnHeader,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Device", "User", "Application", "Mailbox")]
        [string[]]$ObjectTypes,
        [Parameter(Mandatory=$false)]
        [bool]$IsActive,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Directly", "ETL")]
        [string]$AllowUpdate,
        [Parameter(Mandatory=$false)]
        [bool]$AllowExternalUpdate
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $uri = "{0}/apiv1/custom-fields/{1}" -f $Instance, $CustomFieldId
        $headers = @{'x-api-key' = $APIKey}

        # The API requires the full definition on update, so read the current field and change only what was supplied.
        try {
            $current = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
        }
        catch {
            if ($_.Exception.Response.StatusCode.Value__ -eq 404) {
                Write-Error ("Custom field with id {0} was not found." -f $CustomFieldId)
            }
            else {
                Write-Error $_
            }
            return
        }

        $payload = [ordered]@{
            name                  = $current.name
            csvUpdateColumnHeader = $current.csvUpdateColumnHeader
            allowExternalUpdate   = $current.allowExternalUpdate
            isActive              = $current.isActive
            isUserField           = $current.isUserField
            isComputerField       = $current.isComputerField
            isApplicationField    = $current.isApplicationField
            isMailboxField        = $current.isMailboxField
            valueTypeId           = $current.valueTypeId
            updateSourceId        = $current.updateSourceId
        }

        if ($PSBoundParameters.ContainsKey('Name')) { $payload.name = $Name }
        if ($PSBoundParameters.ContainsKey('CSVColumnHeader')) { $payload.csvUpdateColumnHeader = $CSVColumnHeader }
        if ($PSBoundParameters.ContainsKey('IsActive')) { $payload.isActive = $IsActive }
        if ($PSBoundParameters.ContainsKey('AllowExternalUpdate')) { $payload.allowExternalUpdate = $AllowExternalUpdate }
        if ($PSBoundParameters.ContainsKey('ObjectTypes')) {
            $payload.isUserField = ($ObjectTypes -contains "User")
            $payload.isComputerField = ($ObjectTypes -contains "Device")
            $payload.isApplicationField = ($ObjectTypes -contains "Application")
            $payload.isMailboxField = ($ObjectTypes -contains "Mailbox")
        }
        if ($PSBoundParameters.ContainsKey('AllowUpdate')) {
            $payload.updateSourceId = switch ($AllowUpdate) {
                "Directly" {1}
                "ETL"      {2}
            }
        }

        $jsonbody = $payload | ConvertTo-Json

        try {
            if ($PSCmdlet.ShouldProcess(("{0} (id {1})" -f $current.name, $CustomFieldId))) {
                $null = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType 'application/json'
            }
        }
        catch {
            if ($_.Exception.Response.StatusCode.Value__ -eq 409) {
                Write-Error ("Custom field {0} could not be updated. Check that the CSV column header '{1}' is not used by another custom field." -f $CustomFieldId, $payload.csvUpdateColumnHeader)
            }
            else {
                Write-Error $_
            }
        }
    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
