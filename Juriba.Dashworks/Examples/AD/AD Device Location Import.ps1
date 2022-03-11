
<#
.Synopsis
Pulls user data from Get-ADUser and upload to a DW User Location feed

.Description
Takes all users from get-adcomputer (optional server/cred parameters) transforms the fields into a datatable in the format required
for the DW API and then uploads that device data to numbered data feed.

.Parameter Instance
The URI to the Dashworks instance being examined.

.Parameter APIKey
The APIKey for a user with access to the required resources.

.Parameter LocationImportID
The id of the location feed to be used.

.Parameter UserImportId
The id of the user feed in question.

.Parameter ADServer
The name of a DC to connect get-adcomputer to.

.Parameter Credentials
The credentials to use when calling get-adcomputer

.Outputs
Output type [string]
Text confirming the number of rows to be inserted.

#>
[CmdletBinding()]
Param (
    [parameter(Mandatory=$True)]
    [string]$Instance,

    [Parameter(Mandatory=$True)]
    [string]$APIKey,

    [parameter(Mandatory=$True)]
    [string]$LocationImportID,

    [parameter(Mandatory=$True)]
    [string]$DeviceImportId,

    [parameter(Mandatory=$False)]
    [string]$ADServer,

    [parameter(Mandatory=$False)]
    [PSCredential]$Credential
)

$Properties = @("Location")

if ($ADServer)
{
    if ($Credential)
    {
        $ADComputers = get-adcomputer -Filter * -Properties $properties -Server $ADServer -Credential $Credential
    }
    else
    {
        $ADComputers = get-adcomputer -Filter * -Properties $properties -Server $ADServer
    }
}else{
    if ($Credential)
    {
        $ADComputers = get-adcomputer -Filter * -Properties $properties -Credential $Credential
    }
    else
    {
        $ADComputers = get-adcomputer -Filter * -Properties $properties
    }
}

$Locations = @()
$LocationDevices = @{}

foreach($Device in $ADComputers)
{
    if ($null -ne $($Device.Location))
    {
        $Location = Get-DwImportLocation -Instance $APIUri -APIKey $APIKey -ImportID $LocationImportID -LocationName $($Device.Location) -InfoLevel "Full"
        $Locations += $Location
        $LocationDevices = @{$Device.name=$Location.uniqueIdentifier}
    }
}

$JsonLocationArray = @()

foreach($Location in $Locations)
{
    $LocDevices = @()
    foreach($Device in $ADComputers)
    {
        if($LocationDevices[$Device.name] -eq $Location.uniqueIdentifier)
        {
            $LocDevices += "/imports/devices/$DeviceImportId/items/$($Device.name)"
        }
    }
    $JSonObject = [pscustomobject]@{
        uniqueIdentifier = $Location.uniqueIdentifier
        name = $Location.name
        region = $Location.region
        country = $Location.country
        state = $Location.state
        city = $Location.city
        buildingName = $Location.buildingName
        address1 = $Location.address1
        address2 = $Location.address2
        address3 = $Location.address3
        address4 = $Location.address4
        postalCode = $Location.postalCode
        users = $Location.users
        devices = $LocDevices
    }
    $JsonLocationArray += $JSonObject | ConvertTo-Json
}

$PostHeaders = @{
    "content-type" = "application/json"
    "X-API-KEY" = "$APIKey"
}

$RowCount = 0
foreach($Body in $JsonLocationArray)
{
    $Record=$Body|convertFrom-Json
    $uri = "{0}/apiv2/imports/Locations/{1}/items/{2}" -f $Instance, $LocationImportID, $($record.uniqueIdentifier)
    Invoke-RestMethod -Headers $PostHeaders -Uri $uri -Method Patch -Body $Body | out-null
    $RowCount++
}

Return "$RowCount locations updated"
