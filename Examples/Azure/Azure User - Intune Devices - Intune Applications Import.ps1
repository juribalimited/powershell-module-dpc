    <#
    .Synopsis
    A sample script to create Users from Azure AD and Devices and Apps from Intune, linking them together.
    .Description
    Uses the Microsoft Login to generate a token and then queries the Microsoft Graph API to bring in the Devices, Users and Apps, processing them in parallel.
    .Parameter TenantId
    The Directory or tenant ID of the Azure system being connected to.
    .Parameter ClientId
    The Azure Client ID or Application ID connecting.
    .Parameter ClientSecret
    The Azure Client secret of the Client/Application being used to connect.
    .Parameter Instance
    The URI to the Juriba instance being to be used.
    .Parameter APIKey
    The APIKey for a user with access to the required resources.
    .Parameter UserImportID
    The ID of the Juriba Feed set up to bring in the Azure AD Users.
    .Parameter DeviceImportID
    The ID of the Juriba Feed set up to bring in the Intune Devices.
    .Parameter AppImportID
    The ID of the Juriba Feed set up to bring in the Intune Apps. This is usually the same as the Feed ID for the Intune Devices.
    #>

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

#############################################################
##          Create Functions & Get Token
#############################################################

$DeleteHeaders = @{"X-API-KEY" = "$APIKey"}
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
    $accessToken | Add-Member -NotePropertyName ExpiresAt -NotePropertyValue ((get-date).AddSeconds($accessToken.expires_in))
    return $accessToken

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
    Output type [PSObject]
    The PSObject string containing the OAuth2 accessToken returned from the Azure authentication provider along with the additional fields returned and an added ExpiresAt timestamp.
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
        $GraphData = Invoke-RestMethod -Headers @{Authorization = "Bearer $($accessToken)" } -Uri $uri -Method Get -Proxy $Proxy -MaximumRetryCount 3 -RetryIntervalSec 10

        $ScriptBlock=$null

        foreach($entry in $GraphData.Value) 
        {
            $ScriptBlock=$null

            foreach($object_properties in $($entry | Get-Member | where-object{($_.MemberType -eq "NoteProperty") -and ($_.Name -ne '@odata.type')}))
            {
                if($dtResults.Columns.contains($object_properties))
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

            $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)

            $DataRow = $dtResults.NewRow()

            & $ScriptBlock

            $dtResults.Rows.Add($DataRow)
 
        }
        $uri = $GraphData.'@odata.nextLink'
    }
    while ($null -ne $GraphData.'@odata.nextLink')

    return @(,($dtResults))
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

    foreach($Row in $IntuneAppTable.Rows)
    {
        $NewRow = $null
        $NewRow = $dataTable.NewRow()
        $NewRow.uniqueIdentifier = $Row.id
        $NewRow.manufacturer = "InTune Discovered App"
        $NewRow.name = $Row.displayName
        $NewRow.version = $Row.version
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
        $NewRow.computerModel =if($Row.model){$Row.model.subString(0, [System.Math]::Min(50, $Row.model.Length))}else {[DBNULL]::value}
        if ($Row.enrolledDateTime -gt '1753-01-01'){$NewRow.firstSeenDate = $Row.enrolledDateTime}
        if ($Row.lastSyncDateTime -gt '1753-01-01'){$NewRow.lastSeenDate = $Row.lastSyncDateTime}
        $NewRow.serialNumber = $Row.serialNumber
        $NewRow.memoryKb = if($Row.physicalMemoryInBytes){($Row.physicalMemoryInBytes)/1024}else{[DBNULL]::Value}
        $NewRow.macAddress = If($Row.ethernetMacAddress){$Row.ethernetMacAddress}elseif($Row.wiFiMacAddress){$Row.wiFiMacAddress}else{[DBNULL]::Value}
        $NewRow.totalHDDSpaceMb = If($Row.totalStorageSpaceInBytes){$Row.totalStorageSpaceInBytes/(1024*1024)}else{[DBNULL]::Value}
        $NewRow.targetDriveFreeSpaceMb = If($Row.freeStorageSpaceInBytes){$Row.freeStorageSpaceInBytes/(1024*1024)}else{[DBNULL]::Value}
        $NewRow.owner = If($Row.userId){$Row.userId} elseif ($row.usersloggedon){($row.usersloggedon | convertfrom-JSON)[0].userid}else{[DBNULL]::Value}
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
Function Convert-DwAPIUserFromAzure($AzureDataTable){
    [OutputType([System.Data.DataTable])]
    $dataTable = New-Object System.Data.DataTable
    $dataTable.Columns.Add("uniqueIdentifier", [string]) | Out-Null
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
    $dataTable.Columns.Add("UniqueIdentifier", [string]) | Out-Null

    foreach($Row in $AzureDataTable.Rows)
    {
        $NewRow = $null
        $NewRow = $dataTable.NewRow()
        $NewRow.uniqueIdentifier = $Row.userPrincipalName
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
        $NewRow.UniqueIdentifier = $Row.id
        
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
    $uri = "{0}/apiv2/imports/users/{1}/items" -f $Instance, $ImportID

    $DWUserDataTable | Foreach-Object -Parallel {
        $Body = $null
        $Body = $_ | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
        Invoke-RestMethod -Headers $using:Postheaders -Uri $using:uri -Method Post -Body $Body | out-null
    } -Throttle 20
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

    $DWAppDataTable | ForEach-Object -Parallel {
        start-sleep -Milliseconds 50
        $Body = $null
        $Body = $_ | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json -EscapeHandling EscapeNonAscii
        Invoke-RestMethod -Headers $using:Postheaders -Uri $using:uri -Method Post -Body $Body | out-null
    } -Throttle 15
}
$MasterStopwatch =  [system.diagnostics.stopwatch]::StartNew()

# Get Azure access token
$AZToken = Get-AzureAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
write-output "Token Granted in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Restart()

#############################################################
##                  Users
#############################################################

#Delete the existing feed data
$DeleteUsersURI = "{0}/apiv2/imports/users/{1}/items" -F $Instance,$UserImportID
Invoke-RestMethod -Uri $DeleteUsersURI -Method Delete -Headers $DeleteHeaders | Out-Null
write-output "User Feed Data Deleted in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Restart()

# Get Azure AD users
$AzureUserTable = Get-AzDataTable -accessToken $AZToken.access_token -GraphEndpoint 'https://graph.microsoft.com/v1.0/users?$select=id,accountEnabled,ageGroup,assignedLicenses,assignedPlans,businessPhones,city,companyName,consentProvidedForMinor,country,createdDateTime,creationType,deletedDateTime,department,displayName,employeeHireDate,employeeId,employeeOrgData,employeeType,externalUserState,externalUserStateChangeDateTime,faxNumber,givenName,id,identities,imAddresses,isResourceAccount,jobTitle,lastPasswordChangeDateTime,legalAgeGroupClassification,licenseAssignmentStates,mail,mailNickname,mobilePhone,officeLocation,onPremisesDistinguishedName,onPremisesDomainName,onPremisesExtensionAttributes,onPremisesImmutableId,onPremisesLastSyncDateTime,onPremisesProvisioningErrors,onPremisesSamAccountName,onPremisesSecurityIdentifier,onPremisesSyncEnabled,onPremisesUserPrincipalName,otherMails,passwordPolicies,passwordProfile,postalCode,preferredDataLocation,preferredLanguage,provisionedPlans,proxyAddresses,refreshTokensValidFromDateTime,showInAddressList,signInSessionsValidFromDateTime,state,streetAddress,surname,usageLocation,userPrincipalName,userType'
write-output "Graph User data for $($AzureUserTable.Rows.Count) users pulled in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Restart()

# Convert the users table for import
$DWImportUserTable = Convert-DwAPIUserFromAzure -AzureDataTable $AzureUserTable
write-output "User data converted in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Restart()

# Import the users into Dashworks
Invoke-DwImportUserFeedDataTable -Instance $Instance -APIKey $APIKey -ImportId $UserImportID -DWUserDataTable $DWImportUserTable
write-output "User data uploaded in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Restart()

#############################################################
##                  Applications
#############################################################

#Delete the existing feed data
$DeleteAppsURI = "{0}/apiv2/imports/applications/{1}/items" -F $Instance,$AppImportID
Invoke-RestMethod -Uri $DeleteAppsURI -Method Delete -Headers $DeleteHeaders | Out-Null
write-output "Application feed data deleted in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Restart()

#Refresh the token, if needed
If ($AZToken.ExpiresAt -lt (get-date).AddMinutes(5))
    {
      $AZToken = Get-AzureAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
    }

# Get the list of managed apps from InTune
$IntuneManagedAppTable = Get-AzDataTable -accessToken $AZToken.access_token -GraphEndpoint "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps"
write-output "Graph Managed App data for $($IntuneManagedAppTable.Rows.Count) apps pulled in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Restart()

# Convert the Apps list for import
$DWImportAppTable1 = Convert-DwImportManagedAppsFromInTune -IntuneAppTable $IntuneManagedAppTable
write-output "Managed application data converted in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Restart()

# Import the managed apps
Invoke-DwImportAppFeedDataTable -Instance $Instance -APIKey $APIKey -ImportId $AppImportID -DWAppDataTable $DWImportAppTable1
write-output "Managed application data uploaded in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Restart()

# Get the list of detected apps from InTune
$IntuneDetectedAppTable = Get-AzDataTable -accessToken $AZToken.access_token -GraphEndpoint 'https://graph.microsoft.com/v1.0/deviceManagement/detectedApps'
write-output "Graph Detected App data for $($IntuneDetectedAppTable.Rows.Count) apps pulled in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Restart()

# Convert the Apps list for import
$DWImportAppTable2 = Convert-DwImportDiscoveredAppsFromInTune -IntuneAppTable $IntuneDetectedAppTable
write-output "Detected application data converted in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Restart()

# Import the managed apps
Invoke-DwImportAppFeedDataTable -Instance $Instance -APIKey $APIKey -ImportId $AppImportID -DWAppDataTable $DWImportAppTable2
write-output "Detected application data uploaded in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Restart()

#############################################################
##                  Devices
#############################################################

#Refresh the token, if needed
If ($AZToken.ExpiresAt -lt (get-date).AddMinutes(5))
    {
      $AZToken = Get-AzureAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
    }

#Delete the data in the device feed ready for re-population
$DeleteDeviceURI = "{0}/apiv2/imports/devices/{1}/items" -F $Instance,$DeviceImportID
Invoke-RestMethod -Uri $DeleteDeviceURI -Method Delete -Headers $DeleteHeaders
write-output "Device feed data deleted in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Restart()

# Get the list of devices for InTune
$IntuneDeviceTable = Get-AzDataTable -accessToken $AZToken.access_token -GraphEndpoint 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices'
write-output "Graph Device feed data for $($IntuneDeviceTable.Rows.Count) devices pulled in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Restart()

# Convert the list for import
$DWImportDeviceTable = Convert-DwAPIDeviceFromInTune -IntuneDataTable $IntuneDeviceTable
write-output "Device data converted in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Restart()

############################################################################
### Paralell Process each device for import
############################################################################

#Thread safe dictionary to catch graph API errors
$threadSafeDictionary = [System.Collections.Concurrent.ConcurrentDictionary[string,object]]::new()
$threadSafeDictionary.TryAdd('ExpiresAt',$AZToken.ExpiresAt)
$threadSafeDictionary.TryAdd('AccessToken',$AZToken.access_token)

$DWImportDeviceTable | ForEach-Object -Parallel {
    $Device = $_
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
        $accessToken | Add-Member -NotePropertyName ExpiresAt -NotePropertyValue ((get-date).AddSeconds($accessToken.expires_in))
        return $accessToken

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
        Output type [PSObject]
        The PSObject string containing the OAuth2 accessToken returned from the Azure authentication provider along with the additional fields returned and an added ExpiresAt timestamp.
        .Example
        # Get the AccessToken for the credentials passed.
        $accessToken = Get-AzAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
        #>
    }
    $dict = $using:threadSafeDictionary
    $AZToken = ''
    $ExpiresAt = ''
    $dict.TryGetValue('AccessToken',[ref]$AZToken) | out-null
    $dict.TryGetValue('ExpiresAt',[ref]$ExpiresAt) | out-null
    if ($ExpiresAt -lt (get-date).AddMinutes(5))
    {
        $NewAZToken = Get-AzureAccessToken -TenantId $using:TenantId -ClientId $using:ClientId -ClientSecret $using:ClientSecret
        write-output "Refreshed token at $(get-date)"
        $dict.TryUpdate('ExpiresAt',$NewAZToken.ExpiresAt,$ExpiresAt) | out-null
        $dict.TryUpdate('AccessToken',$NewAZToken.access_token,$AZToken) | out-null
        $AZToken=$NewAZToken.access_token
    }
    $DeviceAppsTable = New-Object System.Data.DataTable
    $DeviceAppsTable.Columns.Add("uniqueIdentifier", [string]) | Out-Null
    $DeviceAppsTable.Columns.Add("name", [string]) | Out-Null
    $DeviceAppsTable.Columns.Add("version", [string]) | Out-Null
    $DeviceAppsTable.Columns.Add("manufacturer", [string]) | Out-Null
    $DeviceAppsTable.Columns.Add("installed", [bool]) | Out-Null
    $DeviceAppsTable.Columns.Add("entitled", [bool]) | Out-Null

    #Get Detected Device Applications
    $GraphEndpoint ='https://graph.microsoft.com/v1.0/deviceManagement/manageddevices(''' + $Device.uniqueIdentifier + ''')/detectedApps'
    try{
        $GraphData = Invoke-RestMethod -Headers @{Authorization = "Bearer $($AZToken)" } -Uri $GraphEndpoint -Method Get
    }
    catch{
        $dict.TryAdd($GraphEndpoint,$_) | Out-Null
    }

    foreach($entry in $GraphData.detectedApps)
    {
        $DataRow = $DeviceAppsTable.NewRow()
        $DataRow.uniqueIdentifier = $entry.id
        $DataRow.name = $entry.displayName
        $DataRow.version = if($entry.version){$entry.version}else{[DBNULL]::Value}
        $DataRow.manufacturer = "InTune Discovered App"
        $DataRow.installed = $true
        $DataRow.entitled = $true
        $DeviceAppsTable.Rows.Add($DataRow) | Out-Null
    }
    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$using:APIKey"
    }
    $uri = "{0}/apiv2/imports/applications/{1}/items" -f $using:Instance, $using:AppImportID

    #Get Managed Device Applications if the device has an owner
    if ($_.owner -and (($using:AzureUserTable.Rows.Count) -gt 0))
    {
        $GraphEndpoint ='https://graph.microsoft.com/beta/users(''' + $_.owner + ''')/mobileAppIntentAndStates(''' + $_.uniqueIdentifier +''')'
        $GraphData = Invoke-RestMethod -Headers @{Authorization = "Bearer $($AZToken)"} -Uri $GraphEndpoint -Method Get
        foreach($entry in $GraphData.mobileAppList)
        {
            $DataRow = $DeviceAppsTable.NewRow()
            $DataRow.uniqueIdentifier = $entry.applicationId
            $DataRow.name = $entry.displayName
            $DataRow.version = if($entry.displayVersion){$entry.displayVersion}else{[DBNULL]::Value}
            $DataRow.manufacturer = if($entry.publisher){$entry.publisher}else{[DBNULL]::Value}
            $DataRow.installed = if($entry.installState -eq "unknown"){$false}else{$true}
            $DataRow.entitled = $true
            $DeviceAppsTable.Rows.Add($DataRow) | Out-Null
        }
    }
    if (($_.owner) -and (($using:AzureUserTable.Rows.Count) -gt 0))
    {
        #Set the Owner as the UPN rather than the id of the User
        $dvAZUserTable = New-Object System.Data.DataView($using:AzureUserTable)
        $dvAZUserTable.RowFilter="id='$($_.owner)'"
        if ($dvAZUserTable.userPrincipalName)
        {
            $_.owner = "/imports/users/$using:UserImportID/items/$($dvAZUserTable.userPrincipalName)"
        }else{
            $_.owner = [DBNull]::Value
        }
    }else{
        $_.owner = [DBNull]::Value
    }
    $Body = $null
    $Body = $_ | Select-Object *,applications -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors 

    $applicationsJSON = @()
    ($DeviceAppsTable | Select-Object -Property uniqueIdentifier,entitled,installed) | ForEach-Object {
        $AppObject = "" | select-object applicationDistHierId,applicationBusinessKey,entitled,installed
        $AppObject.applicationDistHierId=$using:AppImportID
        $AppObject.applicationBusinessKey=$_.uniqueIdentifier
        $AppObject.entitled=$_.entitled
        $AppObject.installed=$_.installed
        $applicationsJSON += $AppObject
    }
    $Body.applications = $applicationsJSON
    $Body = $Body | ConvertTo-Json
    $uri = "{0}/apiv2/imports/devices/{1}/items" -f $using:Instance, $using:DeviceImportID

    #Keep the deviceID for error logging
    $DeviceID=$_.uniqueIdentifier

    try{
        Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $Body | out-null
    }
    catch{
        $dict.TryAdd("$uri $DeviceID",$_) | Out-Null
    }
} -Throttle 20
write-output "Device data uploaded in: $($MasterStopwatch.ElapsedMilliseconds)ms"
$MasterStopwatch.Stop()
