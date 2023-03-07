
<#
.Synopsis
Pulls user data from Get-ADUser and upload to a DW User Location feed

.Description
Takes all users from Get-ADUser (optional server/cred parameters) transforms the fields into a datatable in the format required
for the DW API and then uploads that user data to a named or numbered data feed.

.Parameter Instance
The URI to the Dashworks instance being examined.

.Parameter APIKey
The APIKey for a user with access to the required resources.

.Parameter LocationImportID
The id of the location feed to be used.

.Parameter UserImportId
The id of the user feed in question.

.Parameter ADServer
The name of a DC to connect Get-ADUser to.

.Parameter Credentials
The credentials to use when calling Get-ADUser

.Outputs
Output type [string]
Text confirming the number of rows to be inserted.

.Example
# Get the device feed id for the named feed.
Invoke-DwImportUserLocationFeedFromAD -Instance $Instance -APIKey $APIKey -LocationImportID $DeviceImportID -UserImportId $UserImportId -ADServer $ADDomainController -Credential $Creds
#>
[CmdletBinding()]
Param (
    [parameter(Mandatory = $True)]
    [string]$Instance,

    [Parameter(Mandatory = $True)]
    [string]$APIKey,

    [parameter(Mandatory = $True)]
    [string]$LocationImportID,

    [parameter(Mandatory = $True)]
    [string]$UserImportId,

    [parameter(Mandatory = $False)]
    [string]$ADServer,

    [parameter(Mandatory = $False)]
    [PSCredential]$Credential
)

Function Get-StringHash {
    [OutputType([String])]
    Param (
        [parameter(Mandatory = $True)]
        [string]$StringToHash
    )

    $stringAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stringAsStream)
    $writer.write($StringToHash)
    $writer.Flush()
    $stringAsStream.Position = 0
    return (Get-FileHash -InputStream $stringAsStream | Select-Object -property Hash).Hash
}

$Properties = @("StreetAddress", "City", "State", "PostalCode", "co")

if ($ADServer) {
    if ($Credential) {
        $ADUsers = get-aduser -Filter * -Properties $properties -Server $ADServer -Credential $Credential
    }
    else {
        $ADUsers = get-aduser -Filter * -Properties $properties -Server $ADServer
    }
}
else {
    if ($Credential) {
        $ADUsers = get-aduser -Filter * -Properties $properties -Credential $Credential
    }
    else {
        $ADUsers = get-aduser -Filter * -Properties $properties
    }
}

$Locations = @()
$UserLocations = @{}

foreach ($User in $ADUsers) {
    $uniqueIdentifier = $null
    if ("$($User.StreetAddress)$($User.City)$($User.State)$($User.PostalCode)$($User.co)" -ne "") {

        $uniqueIdentifier = Get-StringHash -StringToHash "$($User.StreetAddress)$($User.City)$($User.State)$($User.PostalCode)$($User.co)"

        if ($null -eq $Locations.uniqueidentifier) {
            $Location = New-Object PSObject
            $Location | Add-Member -type NoteProperty -Name 'uniqueIdentifier' -Value $uniqueIdentifier
            $Location | Add-Member -type NoteProperty -Name 'name' -Value $(if ($User.StreetAddress -like '*`n*') { ($User.StreetAddress -split "`n")[0] }else { $User.StreetAddress })
            $Location | Add-Member -type NoteProperty -Name 'region' -Value "No Region Data"
            $Location | Add-Member -type NoteProperty -Name 'country' -Value $User.co
            $Location | Add-Member -type NoteProperty -Name 'state' -Value $User.State
            $Location | Add-Member -type NoteProperty -Name 'city' -Value $User.City
            $Location | Add-Member -type NoteProperty -Name 'buildingName' -Value $(if ($User.StreetAddress -like '*`n*') { ($User.StreetAddress -split "`n")[0] }else { $User.StreetAddress })
            $Location | Add-Member -type NoteProperty -Name 'address1' -Value $(if ($User.StreetAddress -like '*`n*') { ($User.StreetAddress -split "`n")[0] }else { $User.StreetAddress })
            $Location | Add-Member -type NoteProperty -Name 'address2' -Value $(if ($User.StreetAddress -like '*`n*') { ($User.StreetAddress -split "`n")[1] }else { '' })
            $Location | Add-Member -type NoteProperty -Name 'address3' -Value $(if ($User.StreetAddress -like '*`n*') { ($User.StreetAddress -split "`n")[2] }else { '' })
            $Location | Add-Member -type NoteProperty -Name 'address4' -Value $(if ($User.StreetAddress -like '*`n*') { ($User.StreetAddress -split "`n")[3] }else { '' })
            $Location | Add-Member -type NoteProperty -Name 'postalCode' -Value $User.PostalCode
            $Locations += $Location
        }
        elseif (-not $Locations.uniqueidentifier.contains($uniqueIdentifier)) {
            $Location = New-Object PSObject
            $Location | Add-Member -type NoteProperty -Name 'uniqueIdentifier' -Value $uniqueIdentifier
            $Location | Add-Member -type NoteProperty -Name 'name' -Value $(if ($User.StreetAddress -like '*`n*') { ($User.StreetAddress -split "`n")[0].Replace("`r", "") }else { $User.StreetAddress })
            $Location | Add-Member -type NoteProperty -Name 'region' -Value "No Region Data"
            $Location | Add-Member -type NoteProperty -Name 'country' -Value $User.co
            $Location | Add-Member -type NoteProperty -Name 'state' -Value $User.State
            $Location | Add-Member -type NoteProperty -Name 'city' -Value $User.City
            $Location | Add-Member -type NoteProperty -Name 'buildingName' -Value $(if ($User.StreetAddress -like '*`n*') { ($User.StreetAddress -split "`n")[0].Replace("`r", "") }else { $User.StreetAddress })
            $Location | Add-Member -type NoteProperty -Name 'address1' -Value $(if ($User.StreetAddress -like '*`n*') { ($User.StreetAddress -split "`n")[0].Replace("`r", "") }else { $User.StreetAddress })
            $Location | Add-Member -type NoteProperty -Name 'address2' -Value $(if ($User.StreetAddress -like '*`n*') { if ($($User.StreetAddress -split "`n")[1]) { $($User.StreetAddress -split "`n")[1].Replace("`r", "") }else { '' } }else { '' })
            $Location | Add-Member -type NoteProperty -Name 'address3' -Value $(if ($User.StreetAddress -like '*`n*') { if ($($User.StreetAddress -split "`n")[2]) { $($User.StreetAddress -split "`n")[2].Replace("`r", "") }else { '' } }else { '' })
            $Location | Add-Member -type NoteProperty -Name 'address4' -Value $(if ($User.StreetAddress -like '*`n*') { if ($($User.StreetAddress -split "`n")[3]) { $($User.StreetAddress -split "`n")[3].Replace("`r", "") }else { '' } }else { '' })
            $Location | Add-Member -type NoteProperty -Name 'postalCode' -Value $User.PostalCode
            $Locations += $Location
        }
        $UserLocations.Add($($User.SamAccountName), $uniqueIdentifier)
    }
}

$JsonLocationArray = @()

foreach ($Location in $Locations) {
    $LocUsers = @()
    foreach ($User in $ADUsers) {
        if ($UserLocations[$($User.SamAccountName)] -eq $Location.uniqueIdentifier) {
            $LocUsers += "/imports/users/$UserImportId/items/$($User.SamAccountName)"
        }
    }
    $JSonObject = [pscustomobject]@{
        uniqueIdentifier = $Location.uniqueIdentifier
        name             = $Location.name
        region           = $Location.region
        country          = $Location.country
        state            = $Location.state
        city             = $Location.city
        buildingName     = $Location.buildingName
        address1         = $Location.address1
        address2         = $Location.address2
        address3         = $Location.address3
        address4         = $Location.address4
        postalCode       = $Location.postalCode
        users            = $LocUsers
    }
    $JsonLocationArray += $JSonObject | ConvertTo-Json
}

$RowCount = 0

$PostHeaders = @{
    "content-type" = "application/json"
    "X-API-KEY"    = "$APIKey"
}

$DeleteHeaders = @{
    "X-API-KEY" = "$APIKey"
}

$uri = "{0}/apiv2/imports/Locations/{1}/items" -f $Instance, $LocationImportID

#Prior to insert to the Location data, clear down the existing data.
Invoke-RestMethod -Headers $DeleteHeaders -Uri $uri -Method Delete

foreach ($Body in $JsonLocationArray) {
    Invoke-RestMethod -Headers $PostHeaders -Uri $uri -Method Post -Body $Body | out-null
    $RowCount++
}

Return "$RowCount locations added"
