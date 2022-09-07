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
    [string]$UserImportID,

    [Parameter(Mandatory=$True)]
    [string]$DeviceImportID,

    [Parameter(Mandatory=$True)]
    [string]$AppImportID
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
Function Get-AzDataTable{
    Param (
        [parameter(Mandatory=$True)]
        [string]$accessToken,

        [parameter(Mandatory=$True)]
        [string]$GraphEndpoint
    )

    <#
    .Synopsis
    Get a datatable containing all data returned by the endpoint.

    .Description
    Uses the /Graph endpoint to pull all information into a data table for insersion into a SQL database.

    .Parameter accessToken
    The access token for the session you are pulling information from.

    .Parameter GraphEndpoint
    The Graph endpoint you are pulling information from.

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

    $uri=$GraphEndpoint

    $CreateTable = $True

    Do
    {
        $GraphData = Invoke-RestMethod -Headers @{Authorization = "Bearer $($accessToken)" } -Uri $uri -Method Get

        $ScriptBlock=$null

        foreach($object_properties in $($GraphData.Value[0] | Get-Member | where-object{($_.MemberType -eq "NoteProperty") -and ($_.Name -ne '@odata.type')}))
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

        foreach($entry in $GraphData.Value)
        {
            $DataRow = $dtResults.NewRow()

            & $ScriptBlock

            $dtResults.Rows.Add($DataRow)
        }
        $uri = $GraphData.'@odata.nextLink'
    }
    while ($null -ne $GraphData.'@odata.nextLink')

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
    $dataTable.Columns.Add("owner", [string]) | Out-Null

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
        $NewRow.owner = $Row.userId
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
Function Convert-DwImportManagedAppsFromInTune($IntuneAppTable){
    [OutputType([System.Data.DataTable])]
    $dataTable = New-Object System.Data.DataTable

    $dataTable.Columns.Add("uniqueIdentifier", [string]) | Out-Null
    $dataTable.Columns.Add("manufacturer", [string]) | Out-Null
    $dataTable.Columns.Add("name", [string]) | Out-Null
    $dataTable.Columns.Add("version", [string]) | Out-Null

    foreach($Row in $IntuneAppTable.Rows)
    {
        $NewRow = $null
        $NewRow = $dataTable.NewRow()

        $NewRow.uniqueIdentifier = $Row.id
        $NewRow.manufacturer = $Row.publisher
        $NewRow.name = $Row.displayName
        $NewRow.version = $Row.lastModifiedDateTime
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
Function Convert-DwImportDiscoveredAppsFromInTune($IntuneAppTable){
    [OutputType([System.Data.DataTable])]
    $dataTable = New-Object System.Data.DataTable

    $dataTable.Columns.Add("uniqueIdentifier", [string]) | Out-Null
    $dataTable.Columns.Add("manufacturer", [string]) | Out-Null
    $dataTable.Columns.Add("name", [string]) | Out-Null
    $dataTable.Columns.Add("version", [string]) | Out-Null
    $dvdataTable = New-Object System.Data.DataView($dataTable)


    foreach($Row in $dtDeviceApps.Rows)
    {
        $dvdataTable.RowFilter="uniqueIdentifier='$($Row.id)'"
        if ($dvdataTable.count -eq 0)
        {
            $NewRow = $null
            $NewRow = $dataTable.NewRow()

            $NewRow.uniqueIdentifier = $Row.id
            $NewRow.manufacturer = "InTune Discovered App"
            $NewRow.name = $Row.displayName
            $NewRow.version = $Row.version
            $dataTable.Rows.Add($NewRow)
        }
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
Function Convert-DwAPIUserFromAzure($AzureDataTable){
    [OutputType([System.Data.DataTable])]
    $dataTable = New-Object System.Data.DataTable

    $dataTable.Columns.Add("username", [string]) | Out-Null
    $dataTable.Columns.Add("commonObjectName", [string]) | Out-Null
    $dataTable.Columns.Add("displayName", [string]) | Out-Null
    $dataTable.Columns.Add("objectGuid", [string]) | Out-Null
    $dataTable.Columns.Add("lastLogonDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("disabled", [string]) | Out-Null
    $dataTable.Columns.Add("surname", [string]) | Out-Null
    $dataTable.Columns.Add("givenName", [string]) | Out-Null
    $dataTable.Columns.Add("emailAddress", [string]) | Out-Null
    $dataTable.Columns.Add("userPrincipalName", [string]) | Out-Null


    foreach($Row in $AzureDataTable.Rows)
    {
        $NewRow = $null
        $NewRow = $dataTable.NewRow()

        $NewRow.username = $Row.userPrincipalName
        $NewRow.commonObjectName = $Row.userPrincipalName
        $NewRow.displayName = $Row.displayName
        $NewRow.objectGuid = $Row.id
        if ($Row.refreshTokensValidFromDateTime -gt '1753-01-01'){$NewRow.lastLogonDate = $Row.refreshTokensValidFromDateTime}
        $NewRow.disabled = -not $Row.accountEnabled
        $NewRow.surname = $Row.surname
        $NewRow.givenName = $Row.givenName
        $NewRow.emailAddress = $Row.userPrincipalName
        $NewRow.userPrincipalName = $Row.userPrincipalName

        $dataTable.Rows.Add($NewRow)
    }

    Return ,$dataTable

    <#
    .Synopsis
    Return a datatable in the DWAPI User data format from the Get-AzureUsers return table
    .Description
    Takes in a datatable returned from the Get-AzureUsers and strips the fields required for insertion into the Dashworks User API.
    .Parameter IntuneDataTable
    A System.Data.DataTable object returned from the Get-AzureUsers function in the DWAzure module
    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema as used in the DW Users API calls populated with the provided data from Azure.
    .Example
    # Convert the data for use in the DWAPI
    $dtDashworksInput = Convert-DwAPIUserFromAzure -AzureDataTable $dtAzureUserData
    #>
}
function Invoke-DwImportUserFeedDataTable {

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
    Write-DeviceFeedData -Instance $Instance -DWDataTable $dtDashworksInput -ImportId $UserImportID -APIKey $APIKey
    #>

    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,

        [Parameter(Mandatory=$True)]
        [System.Data.DataTable]$DWUserDataTable,

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

    $DeleteHeaders = @{
        "X-API-KEY" = "$APIKey"
    }

    $uri = "{0}/apiv2/imports/users/{1}/items" -f $Instance, $ImportId

    #Prior to insert to the new User data, clear down the existing dataset.
    Invoke-RestMethod -Headers $DeleteHeaders -Uri $uri -Method Delete

    $stopwatch =  [system.diagnostics.stopwatch]::StartNew()

    $DWUserDataTable | Foreach-Object -Parallel {
        $Body = $null
        $Body = $_ | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json

        Invoke-RestMethod -Headers $using:Postheaders -Uri $using:uri -Method Post -Body $Body | out-null
    }
    $stopwatch.Stop()
    Return "$($DWUserDataTable.Rows.Count) users processed in $($stopwatch.ElapsedMilliseconds)ms"
}
function Invoke-DwImportAppFeedDataTable{
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
        [System.Data.DataTable]$DWAppDataTable,

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
            return 'Application feed not found by name or ID'
        }

        $ImportId = Get-DwImportApplicationFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName

        if (-not $ImportId)
        {
            return 'Application feed not found by name or ID'
        }
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = "{0}/apiv2/imports/applications/{1}/items" -f $Instance, $ImportId
    $stopwatch =  [system.diagnostics.stopwatch]::StartNew()

    $DWAppDataTable | ForEach-Object -Parallel {
        $Body = $null
        $Body = $_ | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json -EscapeHandling EscapeNonAscii
        $CallTime += Measure-Command {
        Invoke-RestMethod -Headers $using:Postheaders -Uri $using:uri -Method Post -Body $Body | out-null
        }
    }
    $stopwatch.Stop()
    Return "$($DWAppDataTable.Rows.Count) applications processed in $($stopwatch.ElapsedMilliseconds)ms"
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
        [string]$ImportId,

        [Parameter(Mandatory=$True)]
        [System.Data.DataTable]$DWDeviceAppsTable,

        [Parameter(Mandatory=$True)]
        [string]$AppImportID
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
    $stopwatch =  [system.diagnostics.stopwatch]::StartNew()

    $DWDeviceDataTable | ForEach-Object -Parallel {
        $Body = $null
        $Device = $_
        $Body = $_ | Select-Object *,applications -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors 

        $applicationsJSON = @()
        ($using:DWDeviceAppsTable | Where-Object{$_.DeviceId -eq $($Device.uniqueIdentifier)} | Select-Object -Property id,installState) | ForEach-Object {
            $AppObject = "" | select-object applicationDistHierId,applicationBusinessKey,entitled,installed
            $AppObject.applicationDistHierId=$using:AppImportID
            $AppObject.applicationBusinessKey=$_.id
            if($_.installState -eq "unknown")
            {
                $AppObject.installed=$false
            }else{
                $AppObject.installed=$true
            }
            $AppObject.entitled=$true
            $applicationsJSON += $AppObject
        }
        
        $Body.applications = $applicationsJSON
        $Body = $Body | ConvertTo-Json

        Invoke-RestMethod -Headers $using:Postheaders -Uri $using:uri -Method Post -Body $Body | out-null
    }
    $stopwatch.Stop()
    Return "$($DWDeviceDataTable.Rows.Count) devices processed in $($stopwatch.ElapsedMilliseconds)ms"
}

$ClientId = "c1733be1-4d08-4933-87d0-ba269adbf023"
$TenantId = "f435e8dc-375f-44be-8aba-49a32140fdb3"
$ClientSecret = "-Fc.QEulY1x0Kobg-.IcN136qfEo8QEH.H"
$Instance = "https://triton.internal.juriba.com:8443"
$APIKey= "A21K2prt/wSdBg8L9uxK9lhaT7N2E3VkTt3iHm2Iew1utZt5vnddc1eSA5oSHoqe3idJDZj6k10ctRi4kIGbVw=="
$UserImportID=30
$DeviceImportID=41
$AppImportID=42

# Get Azure access token
$AZToken = Get-AzureAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

# Get Azure AD users
$AzureUserTable = Get-AzDataTable -accessToken $AZToken -GraphEndpoint 'https://graph.microsoft.com/v1.0/users?$select=id,accountEnabled,ageGroup,assignedLicenses,assignedPlans,businessPhones,city,companyName,consentProvidedForMinor,country,createdDateTime,creationType,deletedDateTime,department,displayName,employeeHireDate,employeeId,employeeOrgData,employeeType,externalUserState,externalUserStateChangeDateTime,faxNumber,givenName,id,identities,imAddresses,isResourceAccount,jobTitle,lastPasswordChangeDateTime,legalAgeGroupClassification,licenseAssignmentStates,mail,mailNickname,mobilePhone,officeLocation,onPremisesDistinguishedName,onPremisesDomainName,onPremisesExtensionAttributes,onPremisesImmutableId,onPremisesLastSyncDateTime,onPremisesProvisioningErrors,onPremisesSamAccountName,onPremisesSecurityIdentifier,onPremisesSyncEnabled,onPremisesUserPrincipalName,otherMails,passwordPolicies,passwordProfile,postalCode,preferredDataLocation,preferredLanguage,provisionedPlans,proxyAddresses,refreshTokensValidFromDateTime,showInAddressList,signInSessionsValidFromDateTime,state,streetAddress,surname,usageLocation,userPrincipalName,userType'
# Convert the users table for import
$DWImportUserTable = Convert-DwAPIUserFromAzure -AzureDataTable $AzureUserTable
# Import the users into Dashworks
Invoke-DwImportUserFeedDataTable -Instance $Instance -APIKey $APIKey -ImportId $UserImportID -DWUserDataTable $DWImportUserTable

# Get the list of managed apps from InTune
$IntuneAppTable = Get-AzDataTable -accessToken $AZToken -GraphEndpoint "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps"
# Convert the Apps list for import
$DWImportAppTable = Convert-DwImportAppsFromInTune -IntuneAppTable $IntuneAppTable
# Import the managed apps
Invoke-DwImportAppFeedDataTable -Instance $Instance -APIKey $APIKey -ImportId $AppImportID -DWAppDataTable $DWImportAppTable

# Get the list of devices for InTune
$IntuneDeviceTable = Get-AzDataTable -accessToken $AZToken -GraphEndpoint 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices'
# Convert the list for import
$DWImportDeviceTable = Convert-DwAPIDeviceFromInTune -IntuneDataTable $IntuneDeviceTable
# Iterate each row and set the owner to be the UPN for the user object -- Not always correct, might need to hash match the user list.

$dvAZUserTable = New-Object System.Data.DataView($AzureUserTable)
foreach($Row in $DWImportDeviceTable)
{
    $dvAZUserTable.RowFilter="id='$($Row.owner)'"
    if ($dvAZUserTable.userPrincipalName)
    {
        $Row.owner = "/imports/users/$UserImportID/items/$($dvAZUserTable.userPrincipalName)"
    }else{
        $Row.owner = ""
    }
}

# Create a local table for the storage of the discoverd device app data
$dtDeviceApps = New-Object System.Data.DataTable
# Query each object in parallell and get the app data from them.
$IntuneDeviceTable.ID | ForEach-Object -Parallel {
    Function Get-InTuneDeviceApps{
        [OutputType([PSObject])]
        Param (
            [parameter(Mandatory=$True)]
            [string]$accessToken,

            [parameter(Mandatory=$True)]
            [string]$DeviceID

        )
        $GraphEndpoint ='https://graph.microsoft.com/beta/deviceManagement/manageddevices(''' + $DeviceID + ''')?$expand=detectedApps'

        $dtResults = New-Object System.Data.DataTable
        $dtResults.Columns.Add("Deviceid", [string]) | Out-Null
        $dtResults.Columns.Add("id", [string]) | Out-Null
        $dtResults.Columns.Add("displayName", [string]) | Out-Null
        $dtResults.Columns.Add("version", [string]) | Out-Null
        $dtResults.Columns.Add("sizeInByte", [int]) | Out-Null
        $dtResults.Columns.Add("deviceCount", [int]) | Out-Null
        $dtResults.Columns.Add("installState", [string]) | Out-Null

        $GraphData = Invoke-RestMethod -Headers @{Authorization = "Bearer $($accessToken)" } -Uri $GraphEndpoint -Method Get

        foreach($entry in $GraphData.detectedApps)
        {
            $DataRow = $dtResults.NewRow()
            $DataRow.Deviceid = $Deviceid
            $DataRow.id = $entry.id
            $DataRow.displayName = $entry.displayName
            $DataRow.version = $entry.version
            $DataRow.sizeInByte = $entry.sizeInByte
            $DataRow.deviceCount = $entry.deviceCount
            $DataRow.installState = [DBNull]::Value

            $dtResults.Rows.Add($DataRow) | Out-Null
        }
        return @(,($dtResults))
    }
    #Write-Output $_
    $dtOut = Get-InTuneDeviceApps -accessToken $using:AZToken -DeviceID $_
    $dtDeviceAppsRef = $using:dtDeviceApps
    $dtDeviceAppsRef.Merge($dtOut)
}
# Convert the discovered apps for import (includes a distinct selection)
$dtDiscoveredApps = Convert-DwImportDiscoveredAppsFromInTune -IntuneDataTable $dtDeviceApps
# Import the discovered apps into Dashworks
Invoke-DwImportAppFeedDataTable -Instance $Instance -APIKey $APIKey -ImportId $AppImportID -DWAppDataTable $dtDiscoveredApps

# Get managed apps for each object.
$IntuneDeviceTable | Where-Object{($($_.UserId))} | Select-Object id,userId| ForEach-Object -Parallel {
    Function Get-InTuneManagedApps{
        [OutputType([PSObject])]
        Param (
            [parameter(Mandatory=$True)]
            [string]$accessToken,

            [parameter(Mandatory=$True)]
            [string]$DeviceID,

            [parameter(Mandatory=$True)]
            [string]$UserID

        )
        $GraphEndpoint ='https://graph.microsoft.com/beta/users(''' + $UserID + ''')/mobileAppIntentAndStates(''' + $DeviceID +''')'

        $dtResults = New-Object System.Data.DataTable
        $dtResults.Columns.Add("Deviceid", [string]) | Out-Null
        $dtResults.Columns.Add("id", [string]) | Out-Null
        $dtResults.Columns.Add("displayName", [string]) | Out-Null
        $dtResults.Columns.Add("version", [string]) | Out-Null
        $dtResults.Columns.Add("sizeInByte", [int]) | Out-Null
        $dtResults.Columns.Add("deviceCount", [int]) | Out-Null
        $dtResults.Columns.Add("installState", [string]) | Out-Null

        $GraphData = Invoke-RestMethod -Headers @{Authorization = "Bearer $($accessToken)" } -Uri $GraphEndpoint -Method Get

        foreach($entry in $GraphData.mobileAppList)
        {
            $DataRow = $dtResults.NewRow()
            $DataRow.Deviceid = $Deviceid
            $DataRow.id = $entry.applicationId
            $DataRow.displayName = $entry.displayName
            $DataRow.version = $entry.displayVersion
            $DataRow.installState = $entry.installState

            $dtResults.Rows.Add($DataRow) | Out-Null
        }
        return @(,($dtResults))
    }
    #Write-Output $_
    $dtOut = Get-InTuneManagedApps -accessToken $using:AZToken -DeviceID $_.id -UserId $_.UserId
    $dtDeviceAppsRef = $using:dtDeviceApps
    $dtDeviceAppsRef.Merge($dtOut)
}

Invoke-DwImportDeviceFeedDataTable -Instance $Instance -APIKey $APIKey -ImportId $DeviceImportID -DWDeviceDataTable $DWImportDeviceTable -DWDeviceAppsTable $dtDeviceApps -AppImportID $AppImportID
