
<#
.Synopsis
Pulls user data from Get-ADUser and upload to a DW User Department feed

.Description
Takes all users from Get-ADUser (optional server/cred parameters) transforms the fields into a datatable in the format required
for the DW API and then uploads that user data to a named or numbered data feed.

.Parameter Instance
The URI to the Dashworks instance being examined.

.Parameter APIKey
The APIKey for a user with access to the required resources.

.Parameter DepartmentFeedID
The id of the Department feed to be used.

.Parameter UserFeedId
The id of the user feed in question.

.Parameter ADServer
The name of a DC to connect Get-ADUser to.

.Parameter Credential
The credentials to use when calling Get-ADUser of type PSCredential.

.Outputs
Output type [string]
Text confirming the number of rows to be inserted.

.Example
# Get the device feed id for the named feed.
powershell -File "".\AD User Department Import.ps1" -Instance $Instance -APIKey $APIKey -DepartmentImportID $DepartmentImportID  -UserImportID $UserImportID
#>
[CmdletBinding()]
Param (
    [parameter(Mandatory=$True)]
    [string]$Instance,

    [Parameter(Mandatory=$True)]
    [string]$APIKey,

    [parameter(Mandatory=$True)]
    [string]$DepartmentImportID,

    [parameter(Mandatory=$True)]
    [string]$UserImportID,

    [parameter(Mandatory=$False)]
    [string]$ADServer,

    [parameter(Mandatory=$False)]
    [PSCredential]$Credential
)

Function Get-StringHash{
    [OutputType([String])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$StringToHash
        )

    $stringAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stringAsStream)
    $writer.write($StringToHash)
    $writer.Flush()
    $stringAsStream.Position = 0
    return (Get-FileHash -InputStream $stringAsStream | Select-Object -property Hash).Hash
}


$Properties = @("Department","Company")

if ($ADServer)
{
    if ($Credential)
    {
        $ADUsers = get-aduser -Filter * -Properties $properties -Server $ADServer -Credential $Credential
    }
    else
    {
        $ADUsers = get-aduser -Filter * -Properties $properties -Server $ADServer
    }
}else{
    if ($Credential)
    {
        $ADUsers = get-aduser -Filter * -Properties $properties -Credential $Credential
    }
    else
    {
        $ADUsers = get-aduser -Filter * -Properties $properties
    }
}

$Departments = @()
$UserDepartments = @{}

foreach($User in $ADUsers)
{
    $uniqueIdentifier=$null
    $CompanyUID=$null

    if ("{0}{1}" -f $User.Company, $User.Department -ne "")
    {
        $uniqueIdentifier = Get-StringHash -StringToHash "$($User.Company)#$($User.Department)"

        if ($User.Company)
        {
            $CompanyUID = Get-StringHash -StringToHash $($User.Company)
        }

        if ($null -eq $Departments.uniqueidentifier)
        {
            $Department = New-Object PSObject
            $Department | Add-Member -type NoteProperty -Name 'uniqueIdentifier' -Value $uniqueIdentifier
            $Department | Add-Member -type NoteProperty -Name 'Department' -Value $User.Department
            $Department | Add-Member -type NoteProperty -Name 'CompanyUID' -Value $CompanyUID
            $Department | Add-Member -type NoteProperty -Name 'Company' -Value $User.Company
            $Departments += $Department
        }
        elseif (-not $Departments.uniqueidentifier.contains($uniqueIdentifier))
        {
            $Department = New-Object PSObject
            $Department | Add-Member -type NoteProperty -Name 'uniqueIdentifier' -Value $uniqueIdentifier
            $Department | Add-Member -type NoteProperty -Name 'Department' -Value $User.Department
            $Department | Add-Member -type NoteProperty -Name 'CompanyUID' -Value $CompanyUID
            $Department | Add-Member -type NoteProperty -Name 'Company' -Value $User.Company
            $Departments += $Department
        }
        $UserDepartments.Add($($User.SamAccountName),$uniqueIdentifier)
    }
}

$JsonDepartmentArray = @()
$SeenCompanies = @()
$SeenCompanies += ''

foreach($Department in $Departments)
{
    $DeptUsers = @()
    foreach($User in $ADUsers)
    {
        if($UserDepartments[$($User.SamAccountName)] -eq $Department.uniqueIdentifier)
        {
            $DeptUsers += "/imports/users/$UserImportID/items/$($User.SamAccountName)"
        }
    }
    if (-not $SeenCompanies.Contains($Department.CompanyUID))
    {
        $JSonObject = [pscustomobject]@{
            uniqueIdentifier = $Department.CompanyUID
            name = $Department.Company
        }
        $JsonDepartmentArray += $JSonObject | ConvertTo-Json
        $SeenCompanies += $Department.CompanyUID
    }
    $JSonObject = [pscustomobject]@{
        uniqueIdentifier = $Department.uniqueIdentifier
        name = $Department.Department
        parentUniqueIdentifier = $Department.CompanyUID
        users = $DeptUsers
    }
    $JsonDepartmentArray += $JSonObject | ConvertTo-Json
}

$PostHeaders = @{
    "content-type" = "application/json"
    "X-API-KEY" = "$APIKey"
}

$DeleteHeaders = @{
    "X-API-KEY" = "$APIKey"
}

$uri = "{0}/apiv2/imports/Departments/{1}/items" -f $Instance, $DepartmentImportID

#Prior to insert to the Location data, clear down the existing data.
Invoke-RestMethod -Headers $DeleteHeaders -Uri $uri -Method Delete

$RowCount = 0

foreach($Body in $JsonDepartmentArray)
{
    Invoke-RestMethod -Headers $PostHeaders -Uri $uri -Method Post -Body $Body | out-null
    $RowCount++
}

Return "$RowCount departments added"
