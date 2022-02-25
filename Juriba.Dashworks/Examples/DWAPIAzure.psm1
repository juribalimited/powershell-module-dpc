
Function Get-AzAccessToken{
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


Function Get-AzureUsers([string]$accessToken){
    
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
    while ($users.'@odata.nextLink' -ne $null)

    return @(,($dtResults))
    <#
    .Synopsis
    Get a datatable containing all Azure user data.

    .Description
    Uses the /users Graph endpoint to pull all user information into a data table for insersion into a SQL database.

    .Parameter accessToken
    The access token for the session you are pulling information from 

    .Outputs
    Output type [system.data.datatable]
    A datatable containing all of the rows returned by the /users Graph API Endpoint.

    .Notes
    Any nested data returned by Azure will be pushed into the data table as a string containing the nested JSON.

    .Example
    # Get the user data for the access token passed.
    $dtAzureUserData = Get-AzureUsers -accessToken $AccessToken
    #>
}


Function Get-IntuneDevices([string]$accessToken){
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
    while ($devices.'@odata.nextLink' -ne $null)

    return @(,($dtResults))

    <#
    .Synopsis
    Get a datatable containing all InTune device data.

    .Description
    Uses the /deviceManagement/managedDevices Graph endpoint to pull all device information into a data table for insersion into a SQL database.

    .Parameter accessToken
    The access token for the session you are pulling information from 

    .Outputs
    Output type [system.data.datatable]
    A datatable containing all of the rows returned by the /deviceManagement/managedDevices Graph API Endpoint.

    .Notes
    Any nested data returned by Azure will be pushed into the data table as a string containing the nested JSON.

    .Example
    # Get the InTune data for the access token passed.
    $dtInTuneData = Get-IntuneDevices -accessToken $AccessToken
    #>
}

