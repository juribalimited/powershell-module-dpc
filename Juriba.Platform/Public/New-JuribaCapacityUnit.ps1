function New-JuribaCapacityUnit {
	[alias("New-DwCapacityUnit")]
	<#
		.SYNOPSIS
		Creates capacity unit for a specified project or evegreen.
		.DESCRIPTION
		Creates capacity unit for a specified project or evegreen.
		.PARAMETER Instance
		Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
		.PARAMETER APIKey
		Optional. API key to be provided if not authenticating using Connect-Juriba.
		.PARAMETER ProjectID
		ProjectID of the Project to add capacity unit for.
		.PARAMETER Name
		Name for the capacity unit
		.PARAMETER Description
		Description text for the capacity unit
		.PARAMETER IsDefault
		Define if the new capacity unit is set to default, defaults to false
        .OUTPUTS
        capacityUnitId
		.EXAMPLE
		PS> New-JuribaCapacityUnit @dwparams -ProjectID 4 -Name "Unit 1" -Description "Description" -IsDefault $true
    #>
    [CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory=$false)]
		[string]$Instance,
		[Parameter(Mandatory=$false)]
		[string]$APIKey,
		[parameter(Mandatory=$false)]
		[int]$ProjectID,
		[Parameter(Mandatory=$true)]
		[string]$Name,
		[Parameter(Mandatory=$true)]
		[string]$Description,
		[Parameter(Mandatory=$false)]
		[Boolean]$IsDefault = $false
	)

	$uri = "{0}/apiv1/admin/capacityunits/createCapacityUnit" -f $Instance
	$headers = @{
		'x-api-key' = $apikey
	}
	
	$payload  = @{}
	$payload.Add("name", $Name)
	$payload.Add("description", $Description)
	$payload.Add("IsDefault", $IsDefault)

	if ($ProjectID) {
			
		$payload.Add("mapsToEvergreenUnit", -1)
		$payload.Add("projectId", $ProjectID)
    }

    $jsonbody = $payload | ConvertTo-Json 

    try {
		if($PSCmdlet.ShouldProcess($Name)) {
			$result = Invoke-WebRequest -uri $uri -method POST -headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType 'application/json'
			return ($result.content | convertfrom-json).capacityUnitId
		}
    }
    catch {
        write-error $_
    }											   
}