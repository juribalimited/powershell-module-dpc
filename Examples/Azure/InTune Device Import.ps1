
[CmdletBinding()]
param(
    [parameter(Mandatory=$True)]
    [string]$TenantId,

    [parameter(Mandatory=$True)]
    [string]$ClientId,

    [Parameter(Mandatory=$True)]
    [string]$ClientSecret,

    [parameter(Mandatory=$True)]
    [string]$Instance,

    [parameter(Mandatory=$True)]
    [string]$APIKey,

    [Parameter(Mandatory=$True)]
    [string]$ImportID
)

Function Get-AzureAccessToken{
    [OutputType([String])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$TenantId,

        [parameter(Mandatory=$True)]
        [string]$ClientId,

        [Parameter(Mandatory=$True)]
        [string]$ClientSecret,

        [Parameter(Mandatory=$false)]
        [string]$Scope
    )

    $OAuthURI = "https://login.microsoftonline.com/$TenantId/oauth2/token"

    $OAuthBody=@{}
    $OAuthBody.Add('grant_type','client_credentials')
    $OAuthBody.Add('client_id',$ClientId)
    $OAuthBody.Add('client_secret',$ClientSecret)
    if ($scope)
    {
        $OAuthBody.Add('scope',$scope)
    }
    else
    {
        $OAuthBody.Add('resource','https://graph.microsoft.com')
    }

    $OAuthheaders =
    @{
        "content-type" = "application/x-www-form-urlencoded"
    }

    $accessToken = Invoke-RESTMethod -Method 'POST' -URI $OAuthURI -Body $OAuthBody -Headers $OAuthheaders

    return $accessToken.access_Token
    <#
    .Synopsis
    Gets a session bearer token for the Azure credentials provided.

    .Description
    Takes the three required Azure credentials and returns the OAuth2 access token provided by the Microsoft Graph authentication provider.

    .Parameter TenantId
    The Directory or tenant ID of the Azure system being connected to.

    .Parameter ClientId
    The Client Id or Application ID connecting.

    .Parameter ClientSecret
    The client secret of the client / application being used to connect.

    .Outputs
    Output type [string]
    The text string containing the OAuth2 accessToken returned from the Azure authentication provider.

    .Example
    # Get the AccessToken for the credentials passed.
    $accessToken = Get-AzAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
    #>
}
Function Get-IntuneDeviceTable([string]$accessToken){

    <#
    .Synopsis
    Get a datatable containing all InTune device data.

    .Description
    Uses the /deviceManagement/managedDevices Graph endpoint to pull all device information into a data table for insersion into a SQL database.

    .Parameter accessToken
    The access token for the session you are pulling information from.

    .Outputs
    Output type [system.data.datatable]
    A datatable containing all of the rows returned by the /deviceManagement/managedDevices Graph API Endpoint.

    .Notes
    Any nested data returned by Azure will be pushed into the data table as a string containing the nested JSON.

    .Example
    # Get the InTune data for the access token passed.
    $dtInTuneData = Get-IntuneDevices -accessToken $AccessToken
    #>

    [OutputType([PSObject])]

    $dtResults = New-Object System.Data.DataTable

    $uri='https://graph.microsoft.com/v1.0/deviceManagement/managedDevices'

    $CreateTable = $True

    Do
    {
        $devices = Invoke-RestMethod -Headers @{Authorization = "Bearer $($accessToken)" } -Uri $uri -Method Get

        $ScriptBlock=$null

        foreach($object_properties in $($devices.Value[0] | Get-Member | where-object{$_.MemberType -eq "NoteProperty"}))
        {
            if($CreateTable)
            {
                $DataType = switch ($object_properties.Definition.substring(0,$object_properties.Definition.IndexOf(' ')))
                {
                    'datetime' {'datetime'}
                    'bool' {'boolean'}
                    'long' {'int64'}
                    'string' {'string'}
                    'object' {'string'}
                    default {'string'}
                }
                $dtResults.Columns.Add($object_properties.Name,$datatype) | Out-Null
            }

            $ScriptBlock += 'if ($entry.' + $object_properties.Name + ' -ne $null) {if ($entry.' + $object_properties.Name + '.Value -ne $null) { $DataRow.' + $object_properties.Name + ' = $entry.' + $object_properties.Name + '.Value }else{ if ($entry.' + $object_properties.Name + '.GetType().Name -eq "Object[]") { $DataRow.' + $object_properties.Name + ' = ($entry.' + $object_properties.Name + ' | ConvertTo-JSON).ToString() } else { $DataRow.' + $object_properties.Name + ' = $entry.' + $object_properties.Name + ' } } } else {$DataRow.' + $object_properties.Name + " = [DBNULL]::Value}`n"
        }

        $CreateTable = $False #After the first iteration, don't try to add the data columns

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)

        foreach($entry in $devices.Value)
        {
            $DataRow = $dtResults.NewRow()

            & $ScriptBlock

            $dtResults.Rows.Add($DataRow)
        }

        #$devicesDatatable = $devices.value | Out-DataTable
        #$devicesDatatable.Columns.Add("DistHierId", [int], $DistHierId) | Out-Null

        $uri = $devices.'@odata.nextLink'
    }
    while ($null -ne $devices.'@odata.nextLink')

    return @(,($dtResults))
}
Function Convert-DwAPIDeviceFromInTune($IntuneDataTable){
    [OutputType([System.Data.DataTable])]
    $dataTable = New-Object System.Data.DataTable

    $dataTable.Columns.Add("uniqueIdentifier", [string]) | Out-Null
    $dataTable.Columns.Add("hostname", [string]) | Out-Null
    $dataTable.Columns.Add("operatingSystemName", [string]) | Out-Null
    $dataTable.Columns.Add("operatingSystemVersion", [string]) | Out-Null
    $dataTable.Columns.Add("computerManufacturer", [string]) | Out-Null
    $dataTable.Columns.Add("computerModel", [string]) | Out-Null
    $dataTable.Columns.Add("firstSeenDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("lastSeenDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("serialNumber", [string]) | Out-Null
    $dataTable.Columns.Add("memoryKb", [string]) | Out-Null
    $dataTable.Columns.Add("macAddress", [string]) | Out-Null
    $dataTable.Columns.Add("totalHDDSpaceMb", [string]) | Out-Null
    $dataTable.Columns.Add("targetDriveFreeSpaceMb", [string]) | Out-Null


    foreach($Row in $IntuneDataTable.Rows)
    {
        $NewRow = $null
        $NewRow = $dataTable.NewRow()

        $NewRow.uniqueIdentifier = $Row.id
        $NewRow.hostname = $Row.deviceName
        $NewRow.operatingSystemName = $Row.operatingSystem
        $NewRow.operatingSystemVersion = $Row.osVersion
        $NewRow.computerManufacturer = $Row.manufacturer
        $NewRow.computerModel = $Row.model
        if ($Row.enrolledDateTime -gt '1753-01-01'){$NewRow.firstSeenDate = $Row.enrolledDateTime}
        if ($Row.lastSyncDateTime -gt '1753-01-01'){$NewRow.lastSeenDate = $Row.lastSyncDateTime}
        $NewRow.serialNumber = $Row.serialNumber
        $NewRow.memoryKb = if($Row.physicalMemoryInBytes){($Row.physicalMemoryInBytes)/1024}else{[DBNULL]::Value}
        $NewRow.macAddress = If($Row.ethernetMacAddress){$Row.ethernetMacAddress}elseif($Row.wiFiMacAddress){$Row.wiFiMacAddress}else{[DBNULL]::Value}
        $NewRow.totalHDDSpaceMb = If($Row.totalStorageSpaceInBytes){$Row.totalStorageSpaceInBytes/(1024*1024)}else{[DBNULL]::Value}
        $NewRow.targetDriveFreeSpaceMb = If($Row.freeStorageSpaceInBytes){$Row.freeStorageSpaceInBytes/(1024*1024)}else{[DBNULL]::Value}

        $dataTable.Rows.Add($NewRow)
    }

    Return ,$dataTable

    <#
    .Synopsis
    Return a datatable in the DWAPI Computers data format from the Get-IntuneDevices return table

    .Description
    Takes in a datatable returned from the Get-IntuneDevices and strips the fields required for insertion into the Dashworks Computer API.

    .Parameter IntuneDataTable
    A System.Data.DataTable object returned from the Get-IntuneDevices function in the DWAzure module

    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema as used in the DW Computers API calls populated with the provided data from InTune.

    .Example
    # Convert the data for use in the DWAPI
    $dtDashworksInput = Convert-DWDeviceFromInTune -IntuneDataTable $dtInTuneData
    #>
}
function Invoke-DwImportDeviceFeedDataTable{
    <#
    .Synopsis
    Loops a correctly formatted data table inserting all of the rows it contains.

    .Description
    Takes a System.Data.Datatable object with the columns required for the DwAPI device. Inserts these devices one at a time.

    .Parameter Instance
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for and used.

    .Parameter ImportId
    The id of the device feed to be used.

    .Parameter DWDataTable
    [System.Data.DataTable] Data table containing the fields required to insert data into the DW Device API.

    .Outputs
    Output type [string]
    Text confirming the number of rows to be inserted.

    .Example
    # Get the device feed id for the named feed.
    Write-DeviceFeedData -Instance $Instance -DWDataTable $dtDashworksInput -ImportId $DeviceImportID -APIKey $APIKey
    #>

    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,

        [Parameter(Mandatory=$True)]
        [System.Data.DataTable]$DWDeviceDataTable,

        [Parameter(Mandatory=$True)]
        [string]$APIKey,

        [parameter(Mandatory=$False)]
        [string]$FeedName = $null,

        [parameter(Mandatory=$False)]
        [string]$ImportId
    )


    if (-not $ImportId)
    {
        if (-not $FeedName)
        {
            return 'Device feed not found by name or ID'
        }

        $ImportId = Get-DwImportDeviceFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName

        if (-not $ImportId)
        {
            return 'Device feed not found by name or ID'
        }
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = "{0}/apiv2/imports/devices/{1}/items" -f $Instance, $ImportId

    $RowCount = 0
    foreach($Row in $DWDeviceDataTable)
    {
        $Body = $null
        $Body = $Row | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
        Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $Body | out-null

        $RowCount++
    }

    Return "$RowCount devices added"
}

$AZToken = Get-AzureAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

$IntuneDeviceTable = Get-IntuneDeviceTable -accessToken $AZToken

$DWImportDeviceTable = Convert-DwAPIDeviceFromInTune -IntuneDataTable $IntuneDeviceTable

Invoke-DwImportDeviceFeedDataTable -Instance $Instance -APIKey $APIKey -ImportId $ImportID -DWDeviceDataTable $DWImportDeviceTable
