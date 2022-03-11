
[CmdletBinding()]
param(
    [parameter(Mandatory=$True)]
    [string]$Instance,

    [parameter(Mandatory=$True)]
    [string]$APIKey,

    [Parameter(Mandatory=$True)]
    [string]$ImportID,

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

$Properties = @("OperatingSystem","Location","OperatingSystemVersion","LastLogonTimeStamp","Created")

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

[OutputType([System.Data.DataTable])]
$dataTable = New-Object System.Data.DataTable

$dataTable.Columns.Add("uniqueIdentifier", [string]) | Out-Null
$dataTable.Columns.Add("hostname", [string]) | Out-Null
$dataTable.Columns.Add("operatingSystemName", [string]) | Out-Null
$dataTable.Columns.Add("operatingSystemVersion", [string]) | Out-Null
$dataTable.Columns.Add("firstSeenDate", [datetime]) | Out-Null
$dataTable.Columns.Add("lastSeenDate", [datetime]) | Out-Null

foreach($Device in $ADComputers)
{
    $NewRow = $null
    $NewRow = $dataTable.NewRow()

    $NewRow.uniqueIdentifier = $Device.Name
    $NewRow.hostname = $Device.Name
    $NewRow.operatingSystemName = $Device.OperatingSystem
    $NewRow.operatingSystemVersion = $Device.OperatingSystemVersion
    $NewRow.firstSeenDate = $Device.Created
    $NewRow.lastSeenDate = if ([datetime]::FromFileTime($Device.lastlogontimestamp) -gt '1753-01-01'){[datetime]::FromFileTime($Device.lastlogontimestamp)}else{[DBNull]::Value}

    $dataTable.Rows.Add($NewRow)
}


$Import = Get-DwImportDeviceFeed -Instance $Instance -ApiKey $APIKey -ImportId $ImportId

if (-not $Import)
{
    return 'Device feed not found by ID'
}


$Postheaders = @{
    "content-type" = "application/json"
    "X-API-KEY" = "$APIKey"
}

$uri = "{0}/apiv2/imports/devices/{1}/items" -f $Instance, $ImportId

#Prior to insert to the device data, clear down the existing data.
#Invoke-RestMethod -Headers $DeleteHeaders -Uri $uri -Method Delete

$RowCount = 0
foreach($Row in $dataTable)
{
    $Body = $null
    $Body = $Row | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
    Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $Body | out-null

    $RowCount++
}

Return "$RowCount devices added"