function Set-JuribaCapacityUnit {
    [alias("Set-DwCapacityUnit")]
    <#
        .SYNOPSIS
        Create a new capacity unit
        .DESCRIPTION
        Create a new capacity unit using API v1
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER ProjectID
        ID of the project
        .PARAMETER UnitID
        Id of the unit to modify
        .PARAMETER Name
		Name for the capacity unit
		.PARAMETER Description
		Description text for the capacity unit
		.PARAMETER IsDefault
		Define if the new capacity unit is set to default, defaults to false
        .EXAMPLE
        PS> Set-JuribaCapacityUnit @dwparams -UnitID 1 -ProjectID 4 -Name "Unit 1" -Description "Description" -IsDefault $true
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
		[parameter(Mandatory=$false)]
		[int]$ProjectID,
		[parameter(Mandatory=$true)]
		[int]$UnitID,
		[Parameter(Mandatory=$true)]
		[string]$Name,
		[Parameter(Mandatory=$true)]
		[string]$Description,
		[Parameter(Mandatory=$false)]
		[Boolean]$IsDefault = $false
    )

    $uri = "{0}/apiv1/admin/capacityUnits/{1}/updateCapacityUnit" -f $Instance, $UnitID
	$headers = @{
		'x-api-key' = $apikey
	}
	
	$payload  = @{}
	$payload.Add("capacityUnitId", $UnitID)
	$payload.Add("name", $Name)
	$payload.Add("description", $Description)
	$payload.Add("IsDefault", $IsDefault)
	$payload.Add("projectId", $ProjectID)

    $jsonbody = $payload | ConvertTo-Json 

    try {
		if($PSCmdlet.ShouldProcess($Name)) {
			$result = Invoke-WebRequest -uri $uri -method PUT -headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType 'application/json'
			return ($result.content | convertfrom-json).message
		}
    }
    catch {
        write-error $_
    }											   
}