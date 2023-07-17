

function Add-JuribaCustomFieldValue {
    [alias("Add-DWCustomFieldValue")]
    <#
		.SYNOPSIS
		Sets custom field values.
		.DESCRIPTION
		Sets custom field values using Dashworks API v1.
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
        .OUTPUTS
        New custom field value added successfully
		.EXAMPLE
		PS> Add-JuribaCustomFieldValue @dwparams -CustomField "W11 Path" -Value "W11 Device Upgrade" -ObjectKey 100
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
        [int]$ObjectKey
    )

    $payload = @{
        "fieldName" = $CSVColumnHeader
        "value" = $Value
        "fieldIndex" = $fieldIndex
    }
    
    $jsonbody = $payload | ConvertTo-Json

    $uri = "{0}/apiv1//device/{1}/addCustomField" -f $Instance, $ObjectKey
    $headers = @{'x-api-key' = $APIKey }
    
    try {
        $result = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType 'application/json'
        return ($result.Content).Trim('"')
	}
    catch {
            Write-Error $_
    }
}