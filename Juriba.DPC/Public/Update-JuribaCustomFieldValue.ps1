function Update-JuribaCustomFieldValue {
    [alias("Update-DWCustomFieldValue")]
    <#
		.SYNOPSIS
		Updates custom field value.
		.DESCRIPTION
		Updates custom field value using Dashworks API v1.
		.PARAMETER Instance
		Dashworks instance. For example, https://myinstance.dashworks.app:8443
		.PARAMETER APIKey
		Dashworks API Key.
        .PARAMETER CSVColumnHeader
        CSV Column Header
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
		PS> Update-JuribaCustomFieldValue @dwparams -CustomField "W11 Path" -Value "W11 Device Upgrade" -ObjectKey 100 -ObjectType Device
    #>
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
        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox")]
        [string]$ObjectType
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

    $uri = "{0}/apiv1//{1}/{2}/editCustomField" -f $Instance, $path, $ObjectKey
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
    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}