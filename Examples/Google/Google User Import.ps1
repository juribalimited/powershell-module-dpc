
[CmdletBinding()]
param(
    [parameter(Mandatory=$True)]
    [string]$RefreshToken,

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

Function Get-GoogleAccessToken{
    [OutputType([String])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$RefreshToken,

        [parameter(Mandatory=$True)]
        [string]$ClientId,

        [Parameter(Mandatory=$True)]
        [string]$ClientSecret,

        [Parameter(Mandatory=$false)]
        [string]$Scope
    )

    $OAuthURI = "https://login.microsoftonline.com/$RefreshToken/oauth2/token"

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
    Gets a session bearer token for the Google credentials provided.

    .Description
    Takes the three required Google credentials and returns the OAuth2 access token provided by the Microsoft Graph authentication provider.

    .Parameter RefreshToken
    The Directory or tenant ID of the Google system being connected to.

    .Parameter ClientId
    The Client Id or Application ID connecting.

    .Parameter ClientSecret
    The client secret of the client / application being used to connect.

    .Outputs
    Output type [string]
    The text string containing the OAuth2 accessToken returned from the Google authentication provider.

    .Example
    # Get the AccessToken for the credentials passed.
    $accessToken = Get-AzAccessToken -RefreshToken $RefreshToken -ClientId $ClientId -ClientSecret $ClientSecret
    #>
}
Function Get-GoogleUserTable([string]$accessToken){

    <#
    .Synopsis
    Get a datatable containing all Google user data.

    .Description
    Uses the /users Graph endpoint to pull all user information into a data table for insersion into a SQL database.

    .Parameter accessToken
    The access token for the session you are pulling information from.

    .Outputs
    Output type [system.data.datatable]
    A datatable containing all of the rows returned by the /users Graph API Endpoint.

    .Notes
    Any nested data returned by Google will be pushed into the data table as a string containing the nested JSON.

    .Example
    # Get the user data for the access token passed.
    $dtGoogleUserData = Get-GoogleUsers -accessToken $AccessToken
    #>

    [OutputType([PSObject])]

    $uri='https://graph.microsoft.com/v1.0/users?$select=id,accountEnabled,ageGroup,assignedLicenses,assignedPlans,businessPhones,city,companyName,consentProvidedForMinor,country,createdDateTime,creationType,deletedDateTime,department,displayName,employeeHireDate,employeeId,employeeOrgData,employeeType,externalUserState,externalUserStateChangeDateTime,faxNumber,givenName,id,identities,imAddresses,isResourceAccount,jobTitle,lastPasswordChangeDateTime,legalAgeGroupClassification,licenseAssignmentStates,mail,mailNickname,mobilePhone,officeLocation,onPremisesDistinguishedName,onPremisesDomainName,onPremisesExtensionAttributes,onPremisesImmutableId,onPremisesLastSyncDateTime,onPremisesProvisioningErrors,onPremisesSamAccountName,onPremisesSecurityIdentifier,onPremisesSyncEnabled,onPremisesUserPrincipalName,otherMails,passwordPolicies,passwordProfile,postalCode,preferredDataLocation,preferredLanguage,provisionedPlans,proxyAddresses,refreshTokensValidFromDateTime,showInAddressList,signInSessionsValidFromDateTime,state,streetAddress,surname,usageLocation,userPrincipalName,userType'

    $FirstRun = $True

    Do
    {
        $users = Invoke-RestMethod -Headers @{Authorization = "Bearer $($accessToken)" } -Uri $uri -Method Get

        if($FirstRun)
        {
            $dtResults = New-Object System.Data.DataTable
            $ScriptBlock=$null

            foreach($object_properties in $($users.Value[0] | Get-Member | where-object{$_.MemberType -eq "NoteProperty"}))
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

                $ScriptBlock += 'if ($entry.' + $object_properties.Name + ' -ne $null) {if ($entry.' + $object_properties.Name + '.Value -ne $null) { $DataRow.' + $object_properties.Name + ' = $entry.' + $object_properties.Name + '.Value }else{ if ($entry.' + $object_properties.Name + '.GetType().Name -eq "Object[]") { $DataRow.' + $object_properties.Name + ' = ($entry.' + $object_properties.Name + ' | ConvertTo-JSON).ToString() } else { $DataRow.' + $object_properties.Name + ' = $entry.' + $object_properties.Name + ' } } } else {$DataRow.' + $object_properties.Name + " = [DBNULL]::Value}`n"
            }
        }

        $FirstRun = $False #After the first iteration, don't try to add the data columns

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)

        foreach($entry in $users.Value)
        {
            $DataRow = $dtResults.NewRow()

            & $ScriptBlock

            $dtResults.Rows.Add($DataRow)
        }

        $uri = $users.'@odata.nextLink'
    }
    while ($null -ne $users.'@odata.nextLink')

    return @(,($dtResults))

}
Function Convert-DwAPIUserFromGoogle($GoogleDataTable){
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
    $dataTable.Columns.Add("UniqueIdentifier", [string]) | Out-Null

    foreach($Row in $GoogleDataTable.Rows)
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
        $NewRow.UniqueIdentifier = $Row.id
        
        $dataTable.Rows.Add($NewRow)
    }

    Return ,$dataTable

    <#
    .Synopsis
    Return a datatable in the DWAPI User data format from the Get-GoogleUsers return table

    .Description
    Takes in a datatable returned from the Get-GoogleUsers and strips the fields required for insertion into the Dashworks User API.

    .Parameter IntuneDataTable
    A System.Data.DataTable object returned from the Get-GoogleUsers function in the DWGoogle module

    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema as used in the DW Users API calls populated with the provided data from Google.

    .Example
    # Convert the data for use in the DWAPI
    $dtDashworksInput = Convert-DwAPIUserFromGoogle -GoogleDataTable $dtGoogleUserData
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

    $RowCount = 0

    foreach($Row in $DWUserDataTable)
    {
        $Body = $null
        $Body = $Row | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json

        Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $Body | out-null

        $RowCount++
    }

    Return "$RowCount users added"

}


$AZToken = Get-GoogleAccessToken -RefreshToken $RefreshToken -ClientId $ClientId -ClientSecret $ClientSecret

$GoogleUserTable = Get-GoogleUserTable -accessToken $AZToken

$DWImportUserTable = Convert-DwAPIUserFromGoogle -GoogleDataTable $GoogleUserTable

Invoke-DwImportUserFeedDataTable -Instance $Instance -APIKey $APIKey -ImportId $ImportID -DWUserDataTable $DWImportUserTable




