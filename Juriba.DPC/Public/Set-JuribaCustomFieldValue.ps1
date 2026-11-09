function Set-JuribaCustomFieldValue {
    <#
		.SYNOPSIS
		Updates custom field value.
		.DESCRIPTION
		Updates a custom field value on a device, user, application or mailbox using Juriba DPC API v1.
		.PARAMETER Instance
		Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app
		.PARAMETER APIKey
		Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER CSVColumnHeader
        CSV column header of the custom field to update.
        .PARAMETER Value
        Custom field value
        .PARAMETER fieldIndex
        Only applies to multi value text type, otherwise defaults to 0
        .PARAMETER ObjectKey
        Identity of the object to add the value to
        .PARAMETER ObjectType
        The type of object being updated.
        .OUTPUTS
        Custom field value updated successfully
		.EXAMPLE
		PS> Set-JuribaCustomFieldValue -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -CSVColumnHeader "W11 Path" -Value "W11 Device Upgrade" -ObjectKey 100 -ObjectType Device
    #>
    [alias("Update-JuribaCustomFieldValue")]
    [alias("Update-DWCustomFieldValue")]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [string]$CSVColumnHeader,
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [Parameter(Mandatory = $false)]
        [int]$fieldIndex = 0,
        [Parameter(Mandatory = $true)]
        [int]$ObjectKey,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Device", "User", "Application", "Mailbox")]
        [string]$ObjectType = "Device"
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $path = switch($ObjectType) {
            "Device"        {"device"}
            "User"          {"user"}
            "Application"   {"application"}
            "Mailbox"       {"mailbox"}
        }

        $payload = @{
            "fieldName" = $CSVColumnHeader
            "value" = $Value
            "fieldIndex" = $fieldIndex
        }
        
        $jsonbody = $payload | ConvertTo-Json

        $uri = "{0}/apiv1/{1}/{2}/editCustomField" -f $Instance, $path, $ObjectKey
        $headers = @{'x-api-key' = $APIKey }
        
        try {
            if($PSCmdlet.ShouldProcess($CSVColumnHeader)) {
                $result = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType 'application/json'
                return ($result.Content).Trim('"')
            }
        }
        catch {
            Write-Error $_
            }
        } 
    else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}