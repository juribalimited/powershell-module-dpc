using namespace System.Net
# Input bindings are passed in via param block.
param($Timer)

#Stop on an error so the transform is not run with bad data
$OnErrorActionPreference="stop"
$debugPreference = 'Continue'

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()
# Write an information log with the current time.
Write-Host "INFO: Data Import Triggered at $currentUTCtime."

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}
<#
    .SYNOPSIS
    Import Devices From ServiceNow into a Dashworks Device Feed.

    .DESCRIPTION
    Pulls device hardware information from ServiceNow, then queries this data to return a dataset
    which is then injected into a Dashworks device feed.

    The usernames, passwords and server locations are pulled from a table in the database.

#>
Import-Module Juriba.Platform

function Get-ServiceNowToken {
    param (
            [Parameter(Mandatory=$true)][ValidateSet("OAuth", "Basic")][string] $AuthType,
            [Parameter(Mandatory=$true)][string] $Server,
            [Parameter(Mandatory=$true)][pscredential] $Credential,
            [Parameter(Mandatory=$False)][string] $ClientID,
            [Parameter(Mandatory=$False)][string] $ClientSecret
    )

    $Reply = New-Object -TypeName PSCustomObject

    if ($AuthType -eq 'Basic')
    {
        $pair = "{0}:{1}" -f $Credential.UserName, $Credential.GetNetworkCredential().password
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $basicAuthValue = "Basic $base64"

        #Add the properties to the OAuth return object so that they can be checked later.
        $Reply | Add-Member -NotePropertyName ServerURL -NotePropertyValue $Server
        $Reply | Add-Member -NotePropertyName AuthHeader -NotePropertyValue $basicAuthValue
        $Reply | Add-Member -NotePropertyName expires -NotePropertyValue (get-date).AddDays(100)

    }else{
        #Token doesn't exist or cannot be refreshed: Get a new token and store the values
        $body = [System.Text.Encoding]::UTF8.GetBytes(‘grant_type=password&username=’+[uri]::EscapeDataString($($Credential.UserName))+’&password=’+[uri]::EscapeDataString($($Credential.GetNetworkCredential().password))+’&client_id=’+[uri]::EscapeDataString($ClientID)+’&client_secret=’+[uri]::EscapeDataString($ClientSecret))

        $Reply = Invoke-RESTMethod -Method 'Post' -URI "$($Server)/oauth_token.do" -body $Body -ContentType "application/x-www-form-urlencoded"

        if ($Reply.GetType().Name -eq 'string')
        {
            write-error 'Auth request returned a string. Please check host.'
            $Reply = $null
        }else{
            #Add the properties to the OAuth return object so that they can be checked later.
            $Reply | Add-Member -NotePropertyName expires -NotePropertyValue (get-date).AddSeconds($Reply.expires_in)
            $Reply | Add-Member -NotePropertyName Clientid -NotePropertyValue $Clientid
            $Reply | Add-Member -NotePropertyName ClientSecret -NotePropertyValue $ClientSecret
            $Reply | Add-Member -NotePropertyName ServerURL -NotePropertyValue $Server
            $Reply | Add-Member -NotePropertyName AuthHeader -NotePropertyValue "Bearer $($Reply.access_token)"
            $Reply | Add-Member -NotePropertyName refresh_token_expires -NotePropertyValue (get-date).AddDays(100)
        }
        write-debug "New Auth Token Obtained - expires $($Reply.Expires)"
    }
    return $Reply
}

function Update-ServiceNowToken {
    param (
        [Parameter(Mandatory=$true)][PSObject] $OAuthToken
    )
    
    $Reply = New-Object -TypeName PSCustomObject

    $body = [System.Text.Encoding]::UTF8.GetBytes(‘grant_type=refresh_token&client_id=’+[uri]::EscapeDataString($OAuthToken.ClientID)+’&client_secret=’+[uri]::EscapeDataString($OAuthToken.ClientSecret)+’&refresh_token=’+[uri]::EscapeDataString($OAuthToken.Refresh_Token))
    try{
        $Reply = Invoke-RestMethod -Uri "$($OAuthToken.ServerURL)/oauth_token.do" -Body $Body -ContentType ‘application/x-www-form-urlencoded’ -Method Post

        if ($Reply.GetType().Name -eq 'string')
        {
            write-error 'Auth request returned a string. Please check host.'
            $Reply = $null
        }else{
            #Add the properties to the OAuth return object so that they can be checked later.
            $Reply | Add-Member -NotePropertyName expires -NotePropertyValue (get-date).AddSeconds($Reply.expires_in)
            $Reply | Add-Member -NotePropertyName Clientid -NotePropertyValue $OAuthToken.Clientid
            $Reply | Add-Member -NotePropertyName ClientSecret -NotePropertyValue $OAuthToken.ClientSecret
            $Reply | Add-Member -NotePropertyName ServerURL -NotePropertyValue $OAuthToken.ServerURL
            $Reply | Add-Member -NotePropertyName AuthHeader -NotePropertyValue "Bearer $($Reply.access_token)"
            $Reply | Add-Member -NotePropertyName refresh_token_expires -NotePropertyValue (get-date).AddDays(100)
        }
        #write-output "Auth Token Refreshed - expires $($OAuthToken.expires)" 
    }
    catch{
        write-error "Auth Token Refresh Failed - $_"
    }
    return ,$Reply
}

function Get-ServiceNowTable {
    [OutputType([System.Data.DataTable])] 
<#
    .SYNOPSIS
    Gets table from ServiceNow and writes data back to Dashworks database table 

    .DESCRIPTION
    Uses ServiceNow REST API to read table data and writes data back to a Dashworks database table
    Creates the table in Custom if it does not already exist
    Supports OAuth and Basic Auth 

    .PARAMETER TableName 
    Name of ServiceNow table to import. 

    .PARAMETER DBPath 
    SQLite DB file to write data too.
        
    .PARAMETER DLLPath 
    Path to the System.Data.SQLite.dll file

    .PARAMETER NameValuePairs 
    Optional . Specify name value pairs to be imported from table. 
    If ommited all name value pairs are imported.

    .PARAMETER ChunkSize 
    Specifies number of rows to import from each ServiceNow table at a time. 
    Default is 5000 rows. 

    .PARAMETER UseOAuth 
    If true use OAuth otherwise use Basic Auth. 
    Default is true.

    .INPUTS
    None. You cannot pipe objects to Add-Extension.

    .OUTPUTS
    None. 

    .EXAMPLE
    PS> Get-ServiceNowTableSQLite -TableName cmdb_ci_computer -DLLPath $DLLPath -DBPath $DBPath

    .LINK
    Online version: https://dashworks.atlassian.net/wiki/spaces/DWY/pages/1111949418/ServiceNow+preview

#>
param (
    [Parameter(Mandatory=$true)][string] $TableName,
    [Parameter(Mandatory=$false)][string] $NameValuePairs,
    [Parameter(Mandatory=$false)][string] $ChunkSize = 1000,
    [Parameter(Mandatory=$true)][PSObject] $AuthToken
    )
    $OAuthToken=$AuthToken.PSObject.Copy()

    Write-Host ("INFO: Get-ServiceNowTable")
    Write-Host ("INFO: Table Name: {0}" -f $tablename)
    Write-Host ("INFO: Chunk Size: {0}" -f $ChunkSize)

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Set headers for ServiceNow Requests
    $headers = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
    $headers.Add('Accept','application/json')
    $headers.Add('Content-Type','application/json')

    if ($OAuthToken.expires -lt (Get-date).AddMinutes(10))
    {
        $OAuthToken = Update-ServiceNowToken -OAuthToken $OAuthToken
        [void]$headers.Add('Authorization',$OAuthToken.AuthHeader)
    }
    else{
        [void]$headers.Add('Authorization',$OAuthToken.AuthHeader)
    }

    $method = 'Get'
    $response = $null
    $offset=0
    $limit = $ChunkSize
    $count=$limit

    while ($count -eq $limit)
    {
        #Check to see if the OAuth token is still going to be valid for the request. If not, get a new one.
        if ($OAuthToken.expires -lt (Get-date).AddMinutes(10))
        {
            Write-Host ("INFO: Token Expires at: {0}, current time: {1} - forcing new OAuth token" -f $OAuth.expires, (get-date))
            $OAuthToken = Update-ServiceNowToken -OAuthToken $OAuthToken
            [void]$headers.Remove("Authorization")
            [void]$headers.Add('Authorization',$OAuthToken.AuthHeader)
        }

        # Specify endpoint uri
        $uri="$($OAuthToken.ServerURL)/api/now/table/$TableName"+"?sysparm_limit={1}&sysparm_offset={0}&sysparm_display_value=true" -f $offset, $limit
        if($NameValuePairs){$uri = $uri + '&' + $NameValuePairs}
        Write-Host ("INFO: URI: {0}" -f $URI)
        try{
            $pagedresponse = (Invoke-RestMethod -Headers $headers -Method $method -Uri $uri -ContentType 'application/json' -UseBasicParsing).result
        }catch{
            Write-Host ("ERROR: Service Now request failed")
            Write-Host ("ERROR: StatusCode: {0}" -f $_.Exception.Response.StatusCode.value__)
            Write-Host ("ERROR: StatusDescription: {0}" -f $_.Exception.Response.StatusDescription)
            Write-Host ("ERROR: Message: {0}" -f $_.Exception.Message)
            break;
        }
        $response += $pagedresponse
        $count = $pagedresponse.count
        $offset = $offset + $limit
        Write-Host ("INFO: Read: {0} rows from: {1}" -f $response.Count, $TableName)
    }

    $dtResults = New-Object System.Data.DataTable
    $ScriptBlock=$null

    if ($response.count -gt 0)
    {
        foreach($DataColumn in $($response[0] | Get-Member | where-object{($_.MemberType -eq "NoteProperty")}))
        {
            $GetPopulatedEntryBlock='if($response | where-object{$_.' + $DataColumn.Name + ' -ne [DBNULL]::Value} | select-object -First 1) {$response | where-object{$_.' + $DataColumn.Name + ' -ne [DBNULL]::Value} | select-object -First 1 | Get-Member | where-object{$_.MemberType -eq "NoteProperty"} | where-object{$_.Name -eq ''' + $DataColumn.Name + '''}}'
            $GetPopulatedEntryBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($GetPopulatedEntryBlock)
            $PopulatedOutput = & $GetPopulatedEntryBlock
            if ($PopulatedOutput) {$DataColumn = $PopulatedOutput}

            if ($DataColumn.Definition.substring(0,$DataColumn.Definition.IndexOf(' ')) -eq 'System.Management.Automation.PSCustomObject')
            {
                $datatype = 'string'

                $dtResults.Columns.Add($DataColumn.Name,$datatype) | Out-Null
                $dtResults.Columns.Add($DataColumn.Name + "_link",$datatype) | Out-Null
                $ScriptBlock += 'if ($entry.' + $DataColumn.Name + '.display_value) {$DataRow.' + $DataColumn.Name + ' = $entry.' + $DataColumn.Name + '.display_value} else {$DataRow.' + $DataColumn.Name + " = [DBNULL]::Value};`n"
                $ScriptBlock += 'if ($entry.' + $DataColumn.Name + '.link) {$DataRow.' + $DataColumn.Name + '_link = $entry.' + $DataColumn.Name + '.link.substring($entry.' + $DataColumn.Name + '.link.LastIndexOf(''/'')+1) } else {$DataRow.' + $DataColumn.Name + " = [DBNULL]::Value};`n"
            }
            else {
                $DataType = switch ($DataColumn.Definition.substring(0,$DataColumn.Definition.IndexOf(' ')))
                {
                    'datetime' {'datetime'}
                    'bool' {'boolean'}
                    'long' {'int64'}
                    'string' {'string'}
                    'object' {'string'}
                    default {'string'}
                }
                $dtResults.Columns.Add($DataColumn.Name,$datatype) | Out-Null
                $ScriptBlock += 'if ($entry.' + $DataColumn.Name + ' -ne $null) {$DataRow.' + $DataColumn.Name + ' = $entry.' + $DataColumn.Name + ' } else {$DataRow.' + $DataColumn.Name + " = [DBNULL]::Value};`n"
            }
        }
        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)
        foreach($entry in $response)
        {
            $DataRow = $dtResults.NewRow()

            & $ScriptBlock

            $dtResults.Rows.Add($DataRow)
        }
    }
    return @(,($dtResults))
}

function Merge-ServiceNowTable {
    [OutputType([System.Data.DataTable])] 
    param (
        [Parameter(Mandatory=$True)]
        [System.Data.DataTable] $primaryTable,
        [Parameter(Mandatory=$True)]
        [System.Data.DataTable] $secondaryTable,
        [parameter(Mandatory=$True)]
        [string] $LeftjoinKeyProperty,
        [parameter(Mandatory=$True)]
        [string] $rightjoinkeyproperty,
        [parameter(Mandatory=$True)]
        [hashtable] $AddColumns
    )

    <#
    .Synopsis
    Takes an input of two tables and adds column data from the second table to the first where they can perform a join.

    .Description
    Takes an input of two PSObject tables from Get-ServiceNowTable, then uses the join keys to iterate through the second table and add column data as values to the first.

    .Outputs
    Outputs the same PSObject table with the additional properties

    .Example
    # add user_name from sys_user to cmdb_ci_computer
     Merge-ServiceNowTable -primaryTable $CMDB_CI_Data -secondaryTable $sysUser -LeftjoinKeyProperty "assigned_to" -LeftjoinKeySubProperty "link" -rightjoinkeyproperty "sys_id" -AddColumn "user_name"
    #>
    
    Write-Host ("INFO: Starting merge between serviceNow tables.")
    $dtMerge = $primaryTable.Copy()
    $ScriptBlock=$null
    $LeftJoinField= '$Row.' + $LeftjoinKeyProperty
    $ScriptBlock = '$joinRow = $secondaryTable.select("'+ $rightjoinkeyproperty + '=''$(' + $LeftJoinField + ')''")' + "`n"

    $AddedColumnList = ''
    Foreach ($AddColumn in $AddColumns.GetEnumerator()) {
        if (!$dtMerge.Columns.Contains($AddColumn.Value))
        {
            $dtMerge.Columns.Add($AddColumn.Value) | Out-Null
        }
        $ScriptBlock += '$Row.' + $($AddColumn.Value) + ' = $joinRow.' + $($AddColumn.Name) + "`n"
        if ($AddColumn.Value -eq $AddColumn.Name) {
            $AddedColumnList += ", $($AddColumn.Name)"
        }
        else {
            $AddedColumnList += ", $($AddColumn.Name) as $($AddColumn.Value)"
        }
    }
    $AddedColumnList = $AddedColumnList.Substring(2)

    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)

    Foreach ($Row in $dtMerge) {
        & $ScriptBlock
    }

    <#$primaryTable | ForEach-Object -Parallel {
        $Row = $_
        if ($Using:LeftjoinKeySubProperty) {
                if ($Using:LeftjoinKeySubProperty -eq 'Link') {
                    $leftjoinkeyfull = $Row.$Using:LeftjoinKeyProperty.$Using:LeftjoinKeySubProperty
                        If ($leftjoinkeyfull) {
                            $leftjoinkey = $leftjoinkeyfull.substring($leftjoinkeyfull.LastIndexOf("/")+1,$leftjoinkeyfull.Length-($leftjoinkeyfull.LastIndexOf("/")+1))
                            }
                    } 
                else {
                    $leftjoinkey = $Row.$Using:LeftjoinKeyProperty.$Using:LeftjoinKeySubProperty
                }
            } else {
            $leftjoinkey = $Row.$Using:LeftjoinKeyProperty
        }
            
        If ($leftjoinkey) {

            Foreach ($AddColumn in $Using:AddColumns) {
                $AddColumnValue = ($Using:secondaryTable | Where-Object -Property $Using:rightjoinkeyproperty -eq $leftjoinkey).$AddColumn
                $Row | Add-Member -MemberType 'NoteProperty' -Name $AddColumn -Value $AddColumnValue -Force
            }
        
    } }-ThrottleLimit 25#>

    Write-Host ("INFO: Finished merge between serviceNow tables. $AddedColumnList added to primary table.")
    return @(,($dtMerge)) 
}

function Convert-DwAPIDeviceFromServiceNowCMDB_CI_Computer {
    [OutputType([System.Data.DataTable])]
    Param(
        [Parameter(Mandatory=$True)]
        [System.Data.DataTable] $ServiceNowDataTable,
        [Parameter(Mandatory=$false)][string] $UserFeedId = 1
    )
    
    <#
    .Synopsis
    Return a datatable in the DWAPI Computers data format from the Get-ServiceNowTable for cmdb_ci_computer

    .Description
    Takes in a datatable returned from the Get-ServiceNowTable and strips the fields required for insertion into the Dashworks Computer API.

    .Parameter IntuneDataTable
    A System.Data.DataTable object returned from the Get-ServiceNowTable function in the DWAzure module

    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema as used in the DW Computers API calls populated with the provided data from serviceNow CMDB_CI_Computer.

    .Example
    # Convert the data for use in the DWAPI
    $dtDashworksInput = Convert-DwAPIDeviceFromServiceNowCMDB_CI_Computer -SerivceNowDataTable $dtCMDB_CI_Computer -UserFeedID 3
    #>

    Write-Host ("INFO: Starting conversion for CMDB_CI_Computer to DWAPI format.")

    $dataTable = New-Object System.Data.DataTable
    $dataTable.Columns.Add("uniqueIdentifier", [string]) | Out-Null
    $dataTable.Columns.Add("hostname", [string]) | Out-Null
    $dataTable.Columns.Add("operatingSystemName", [string]) | Out-Null
    $dataTable.Columns.Add("operatingSystemVersion", [string]) | Out-Null
    $dataTable.Columns.Add("operatingSystemServicePack", [string]) | Out-Null
    $dataTable.Columns.Add("computerManufacturer", [string]) | Out-Null
    $dataTable.Columns.Add("computerModel", [string]) | Out-Null
    $dataTable.Columns.Add("chassisType", [string]) | Out-Null
    $dataTable.Columns.Add("virtualMachine", [Boolean]) | Out-Null
    $dataTable.Columns.Add("purchaseDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("serialNumber", [string]) | Out-Null
    $dataTable.Columns.Add("processorCount", [string]) | Out-Null
    $dataTable.Columns.Add("processorSpeed", [string]) | Out-Null
    $dataTable.Columns.Add("processorManufacturer", [string]) | Out-Null
    $dataTable.Columns.Add("totalHDDSpaceMb", [string]) | Out-Null
    $dataTable.Columns.Add("memoryMB", [string]) | Out-Null
    $dataTable.Columns.Add("assetTag", [string]) | Out-Null
    $dataTable.Columns.Add("warrantyDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("owner", [string]) | Out-Null

    foreach ($Row in $ServiceNowDataTable) {
            
        $NewRow = $null
        $NewRow = $dataTable.NewRow()
        $NewRow.uniqueIdentifier = $Row.sys_id
        $NewRow.hostname = $Row.name
        if ($Row.os -ne '') {$NewRow.operatingSystemName = $Row.os}
        if ($Row.os_version -ne '') {$NewRow.operatingSystemVersion = $Row.os_version}
        if ($Row.os_service_pack -ne '') {$NewRow.operatingSystemServicePack = $Row.os_service_pack}
        $NewRow.computerManufacturer = $Row.manufacturer.display_value
        $NewRow.computerModel = $Row.model_id.display_value
        $NewRow.chassisType = $Row.form_factor
        $NewRow.virtualMachine = $Row.virtual
        if ($Row.purchase_date -ne '') {$NewRow.purchaseDate = $Row.purchase_date}
        if ($Row.serial_number -ne '') {$NewRow.serialNumber = $Row.serial_number}
        if ($Row.cpu_count -ne '') {$NewRow.processorCount = $Row.cpu_count}
        if ($Row.cpu_speed -ne '') {$NewRow.processorSpeed = ([int]$Row.cpu_speed)}
        if ($Row.cpu_type -ne '') {$NewRow.processorManufacturer = $Row.cpu_type}
        if ($Row.disk_space -gt 0) {$NewRow.totalHDDSpaceMb = ([int]$Row.disk_space)*1024}
        if ($Row.ram -gt 0) {$NewRow.memoryMB = ([int]$Row.ram)*1024}
        $NewRow.assetTag = $Row.asset_tag
        if ($Row.warranty_expiration -ne '') {$NewRow.warrantyDate = $Row.warranty_expiration}
        if ($Row.user_name) {$NewRow.owner = ("/imports/users/{0}/items/{1}" -f $UserFeedId, $Row.user_name)}
        $dataTable.Rows.Add($NewRow)
    }

    Write-Host ("INFO: Finished conversion for CMDB_CI_Computer to DWAPI format.")
    Return @(,($dataTable))
}

function Convert-DwAPIDeviceFromServiceNowAlm_Asset{
    [OutputType([System.Data.DataTable])]
    Param(
        [Parameter(Mandatory=$True)][System.Data.DataTable] $ServiceNowDataTable,
        [Parameter(Mandatory=$false)][string] $UserFeedId = "1",
        [parameter(Mandatory=$False)][hashtable]$CustomFields = @{}
    )

    <#
    .Synopsis
    Return a datatable in the DWAPI Computers data format from the Get-ServiceNowTable for cmdb_ci_computer

    .Description
    Takes in a datatable returned from the Get-ServiceNowTable and strips the fields required for insertion into the Dashworks Computer API.

    .Parameter IntuneDataTable
    A System.Data.DataTable object returned from the Get-ServiceNowTable function in the DWAzure module

    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema as used in the DW Computers API calls populated with the provided data from serviceNow CMDB_CI_Computer.

    .Example
    # Convert the data for use in the DWAPI
    $dtDashworksInput = Convert-DwAPIDeviceFromServiceNowCMDB_CI_Computer -SerivceNowDataTable $dtCMDB_CI_Computer -UserFeedID 3
    #>

    Write-Host ("INFO: Starting conversion for ALM_Asset to DWAPI format.")

    $dataTable = New-Object System.Data.DataTable
    $dataTable.Columns.Add("uniqueIdentifier", [string]) | Out-Null
    $dataTable.Columns.Add("hostname", [string]) | Out-Null
    $dataTable.Columns.Add("operatingSystemName", [string]) | Out-Null
    $dataTable.Columns.Add("operatingSystemVersion", [string]) | Out-Null
    $dataTable.Columns.Add("operatingSystemServicePack", [string]) | Out-Null
    $dataTable.Columns.Add("computerManufacturer", [string]) | Out-Null
    $dataTable.Columns.Add("computerModel", [string]) | Out-Null
    $dataTable.Columns.Add("chassisType", [string]) | Out-Null
    $dataTable.Columns.Add("virtualMachine", [string]) | Out-Null
    $dataTable.Columns.Add("purchaseDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("buildDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("serialNumber", [string]) | Out-Null
    $dataTable.Columns.Add("processorCount", [string]) | Out-Null
    $dataTable.Columns.Add("processorSpeed", [string]) | Out-Null
    $dataTable.Columns.Add("processorManufacturer", [string]) | Out-Null
    $dataTable.Columns.Add("totalHDDSpaceMb", [string]) | Out-Null
    $dataTable.Columns.Add("memoryMB", [string]) | Out-Null
    $dataTable.Columns.Add("assetTag", [string]) | Out-Null
    $dataTable.Columns.Add("warrantyDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("owner", [string]) | Out-Null
    ##Custom Fields
    if ($CustomFields.count -gt 0)
    {
        foreach($CustomFieldName in $CustomFields.GetEnumerator())
        {
            $dataTable.Columns.Add($CustomFieldName.name, [string]) | Out-Null
        }
    }

    foreach ($Row in $ServiceNowDataTable) {

        $NewRow = $null
        $NewRow = $dataTable.NewRow()
        $NewRow.uniqueIdentifier = $Row.sys_id
        $NewRow.hostname = $Row.asset_tag
        if ($Row.os -ne [DBNULL]::Value) {$NewRow.operatingSystemName = $Row.os}
        if ($Row.os_version -ne [DBNULL]::Value) {$NewRow.operatingSystemVersion = $Row.os_version}
        if ($Row.os_service_pack -ne [DBNULL]::Value) {$NewRow.operatingSystemServicePack = $Row.os_service_pack}
        $NewRow.computerManufacturer = $Row.manufacturer
        if ($Row.model.Length -gt 50) {$NewRow.computerModel = $Row.model.substring(0,50)} else {$NewRow.computerModel = $Row.model}
        $NewRow.chassisType = $Row.form_factor
        if ($Row.virtual -ne [DBNULL]::Value) {$NewRow.virtualMachine = $Row.virtual}
        if ($Row.purchase_date -ne [DBNULL]::Value) {$NewRow.purchaseDate = $Row.purchase_date}
        if ($Row.install_date -ne [DBNULL]::Value) {$NewRow.buildDate = $Row.install_date}
        if ($Row.serial_number -ne [DBNULL]::Value) {$NewRow.serialNumber = $Row.serial_number}
        if ($Row.cpu_count -ne [DBNULL]::Value) {$NewRow.processorCount = $Row.cpu_count}
        if ($Row.cpu_speed -ne [DBNULL]::Value) {$NewRow.buildDate = ([int]$Row.cpu_speed)}
        if ($Row.cpu_type -ne [DBNULL]::Value) {$NewRow.processorManufacturer = $Row.cpu_type}
        if ($Row.disk_space -ne [DBNULL]::Value) {$NewRow.totalHDDSpaceMb = ([int]$Row.disk_space)*1024}
        if ($Row.ram -ne [DBNULL]::Value) {$NewRow.memoryMB = ([int]$Row.ram)*1024}
        $NewRow.assetTag = $Row.asset_tag
        if ($Row.warranty_expiration -ne [DBNULL]::Value) {$NewRow.warrantyDate = $Row.warranty_expiration}
        if ($Row.user_name -ne [DBNULL]::Value) {$NewRow.owner = ("/imports/users/{0}/items/{1}" -f $UserFeedId, $Row.user_name)} else {$NewRow.owner = [DBNULL]::Value}
        if ($CustomFields.count -gt 0)
        {
            foreach($CustomFieldName in $CustomFields.GetEnumerator())
            {
                if ($CustomFieldName.name -like '*_static')
                {
                    $NewRow.$($CustomFieldName.name) = $CustomFieldName.value
                }
                elseif ($Row.$($CustomFieldName.value) -ne [DBNULL]::Value) {$NewRow.$($CustomFieldName.name) = $Row.$($CustomFieldName.value)}
            }
        }
        $dataTable.Rows.Add($NewRow)
    }

    Write-Host ("INFO: Finished conversion for ALM_Asset to DWAPI format.")
    Return @(,($dataTable))
}

function Convert-DwAPIUserFromServiceNowSys_User {
    [OutputType([System.Data.DataTable])]
    Param(
        [Parameter(Mandatory=$True)][System.Data.DataTable] $ServiceNowDataTable,
        [parameter(Mandatory=$False)][hashtable]$CustomFields = @{}
    )
    
    <#
    .Synopsis
    Return a datatable in the DWAPI Computers data format from the Get-ServiceNowTable for sys_user

    .Description
    Takes in a datatable returned from the Get-ServiceNowTable and strips the fields required for insertion into the Dashworks User API.

    .Parameter IntuneDataTable
    A System.Data.DataTable object returned from the Get-ServiceNowTable function in the DWAzure module

    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema as used in the DW Users API calls populated with the provided data from serviceNow sys_user.

    .Example
    # Convert the data for use in the DWAPI
    $dtDashworksInput = Convert-DwAPIUserFromServiceNowSys_User -SerivceNowDataTable $dtSysUser
    #>

    Write-Host ("INFO: Starting conversion for Sys_User to DWAPI format.")

    $dataTable = New-Object System.Data.DataTable
    $dataTable.Columns.Add("uniqueIdentifier", [string]) | Out-Null
    $dataTable.Columns.Add("Username", [string]) | Out-Null
    $dataTable.Columns.Add("commonObjectName", [string]) | Out-Null
    $dataTable.Columns.Add("displayName", [string]) | Out-Null
    $dataTable.Columns.Add("objectGuid", [string]) | Out-Null
    $dataTable.Columns.Add("lastLogonDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("disabled", [boolean]) | Out-Null
    $dataTable.Columns.Add("surname", [string]) | Out-Null
    $dataTable.Columns.Add("givenName", [string]) | Out-Null
    $dataTable.Columns.Add("emailAddress", [string]) | Out-Null
    $dataTable.Columns.Add("userPrincipalName", [string]) | Out-Null
    ## Custom Fields
    if ($CustomFields.count -gt 0)
    {
        foreach($CustomFieldName in $CustomFields.GetEnumerator())
        {
            $dataTable.Columns.Add($CustomFieldName.name, [string]) | Out-Null
        }
    }

    foreach ($Row in $ServiceNowDataTable) {
        $NewRow = $null
        $NewRow = $dataTable.NewRow()
        $NewRow.uniqueIdentifier = $Row.sys_id
        $NewRow.Username = $Row.user_name
        $NewRow.commonObjectName = $Row.user_name
        $NewRow.displayName = $Row.name
        $NewRow.objectGuid = $Row.u_correlation_id
        if ($Row.last_login_time -ne '') {$NewRow.lastLogonDate = $Row.last_login_time}
        If ($Row.active -eq $true) {$NewRow.disabled = $false} else {$NewRow.disabled = $true}
        $NewRow.surname = $Row.last_name
        $NewRow.givenName = $Row.first_name
        if ($Row.email -like '*@*.*') {$NewRow.emailAddress = $Row.email} else {$NewRow.emailAddress = "no.valid.email.set@check.source.data"}
        $NewRow.userPrincipalName = $Row.name
        ## Custom Fields
        if ($CustomFields.count -gt 0)
        {
            foreach($CustomFieldName in $CustomFields.GetEnumerator())
            {
                if ($Row.$($CustomFieldName.value) -ne [DBNULL]::Value) {$NewRow.$($CustomFieldName.name) = $Row.$($CustomFieldName.value)}
            }
        }

        if ($Row.user_name -ne [System.DBNull]::Value)
        {
            $dataTable.Rows.Add($NewRow)
        }
    }

    Write-Host ("INFO: Finished conversion for Sys_User to DWAPI format.")
    Return ,$dataTable
}

function Convert-DwAPIDeptFromServiceNowSys_User {
    [OutputType([System.Data.DataTable])]
    Param(
        [Parameter(Mandatory=$True)]
        [System.Data.DataTable] $UserDataTable,
        [Parameter(Mandatory=$false)]
        [string] $UserFeedId = 1
    )

    <#
    .Synopsis
    Return a datatable in the DWAPI department data format from the Get-ServiceNowTable for cmn_department

    .Description
    Takes in a datatable returned from the Get-ServiceNowTable and strips the fields required for insertion into the Dashworks Department API.

    .Parameter ServiceNowDataTable
    A System.Data.DataTable object returned from the Get-ServiceNowTable function

    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema as used in the DW Users API calls populated with the provided data from serviceNow cmn_department.

    .Example
    # Convert the data for use in the DWAPI
    $dtDashworksInput = Convert-DwAPIDeptFromServiceNowCMN_Department -SerivceNowDataTable $dtDepartment
    #>
    Write-Host ("INFO: Starting conversion for cmn_department to DWAPI format.")

    $dataTable = New-Object System.Data.DataTable
    $dataTable.Columns.Add("uniqueIdentifier", [string]) | Out-Null
    $dataTable.Columns.Add("name", [string]) | Out-Null
    $dataTable.Columns.Add("parentUniqueIdentifier", [string]) | Out-Null
    $dataTable.Columns.Add("Users", [array]) | Out-Null

    foreach ($Row in $UserDataTable.Rows | where-object{$_.company_link -ne [DBNull]::Value -and $null -ne $_.company_link} | Select-Object company,company_link -unique)
    {
        $NewRow = $null
        $NewRow = $dataTable.NewRow()
        $NewRow.uniqueIdentifier = $Row.company_link
        $NewRow.name = $Row.company
        $dataTable.Rows.Add($NewRow)
    }

    foreach ($Row in $UserDataTable.Rows | Select-Object department, company_link, department_link -unique)
    {
        if ($Row.department_link -ne [DBNull]::Value)
        {
            $NewRow = $null
            $NewRow = $dataTable.NewRow()
            $NewRow.uniqueIdentifier = $Row.department_link
            $NewRow.name = $Row.department
            $NewRow.parentUniqueIdentifier = $Row.company_link
            $dataTable.Rows.Add($NewRow)
        }
    }


    foreach ($Row in $dataTable.Rows)
    {
        $AddUsers = @()
        if ($Row.parentUniqueIdentifier -ne [dbnull]::value) {
            #Has department
            foreach($user in $UserDataTable.Select("department_link = '$($Row.uniqueIdentifier)'"))
            {
                $AddUsers += ("/imports/users/{0}/items/{1}" -f $UserFeedId, $user.user_name)
            }
        }
        else
        {
            if ($UserDataTable.Columns.Contains("company_link"))
            {
                if ($UserDataTable.Columns.Contains("department_link"))
                {
                    #Add those with no listed department against the company
                    foreach($user in $UserDataTable.Select("company_link = '$($Row.uniqueIdentifier)' AND department_link is null"))
                    {
                        $AddUsers += ("/imports/users/{0}/items/{1}" -f $UserFeedId, $user.user_name)
                    }
                    #Add those with a department
                    foreach($user in $UserDataTable.Select("department_link = '$($Row.uniqueIdentifier)'"))
                    {
                        $AddUsers += ("/imports/users/{0}/items/{1}" -f $UserFeedId, $user.user_name)
                    }
                }else{
                    #Has a company only
                    foreach($user in $UserDataTable.Select("company_link = '$($Row.uniqueIdentifier)' AND department_link is null"))
                    {
                        $AddUsers += ("/imports/users/{0}/items/{1}" -f $UserFeedId, $user.user_name)
                    }
                }
            }else{
                if ($UserDataTable.Columns.Contains("department_link"))
                {
                    #Add those with a company but no department
                    foreach($user in $UserDataTable.Select("department_link = '$($Row.uniqueIdentifier)' AND department_link is not null"))
                    {
                        $AddUsers += ("/imports/users/{0}/items/{1}" -f $UserFeedId, $user.user_name)
                    }
                }
            }
        }
        $Row.Users = $AddUsers
    }

    Write-Host ("INFO: Finished conversion for cmn_department to DWAPI format.")
    Return ,$dataTable
}

function Convert-DwAPIDeptFromServiceNowCMN_Department {
    [OutputType([System.Data.DataTable])]
    Param(
        [Parameter(Mandatory=$True)]
        [PSObject] $ServiceNowDataTable,
        [Parameter(Mandatory=$false)]
        [PSObject] $UserDataTable,
        [Parameter(Mandatory=$false)]
        [string] $UserFeedId = 1
    )
    
    <#
    .Synopsis
    Return a datatable in the DWAPI department data format from the Get-ServiceNowTable for cmn_department

    .Description
    Takes in a datatable returned from the Get-ServiceNowTable and strips the fields required for insertion into the Dashworks Department API.

    .Parameter ServiceNowDataTable
    A System.Data.DataTable object returned from the Get-ServiceNowTable function

    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema as used in the DW Users API calls populated with the provided data from serviceNow cmn_department.

    .Example
    # Convert the data for use in the DWAPI
    $dtDashworksInput = Convert-DwAPIDeptFromServiceNowCMN_Department -SerivceNowDataTable $dtDepartment
    #>
    Write-Host ("INFO: Starting conversion for cmn_department to DWAPI format.")

    $dataTable = New-Object System.Data.DataTable
    $dataTable.Columns.Add("uniqueIdentifier", [string]) | Out-Null
    $dataTable.Columns.Add("name", [string]) | Out-Null
    $dataTable.Columns.Add("code", [string]) | Out-Null
    $dataTable.Columns.Add("costCentre", [string]) | Out-Null
    $dataTable.Columns.Add("parentUniqueIdentifier", [string]) | Out-Null
    $dataTable.Columns.Add("Users", [array]) | Out-Null

    foreach ($Row in $ServiceNowDataTable) {
            
        $NewRow = $null
        $NewRow = $dataTable.NewRow()
        $NewRow.uniqueIdentifier = $Row.sys_id
        $NewRow.name = $Row.name
        $NewRow.code = $Row.id
        $NewRow.costCentre = $Row.cost_center
        if ($Row.parent -ne '') {$NewRow.parentUniqueIdentifier = $Row.Parent}
        $AddUsers = @()
        
        if ($UserDataTable -and $UserFeedId) {
            foreach ($user in $UserDataTable) {
                if ($user.department -ne '') {
                    $link = $user.department.link
                    $DeptID = $link.substring($link.LastIndexOf('/')+1,$link.Length - ($link.LastIndexOf('/')+1))
                    if ($DeptID -eq $row.sys_id) {
                        $username = ("/imports/users/{0}/items/{1}" -f $UserFeedId, $user.user_name)
                        $AddUsers += $username
                    }
                }
            }                
        }
        $NewRow.Users = $AddUsers   
        $dataTable.Rows.Add($NewRow)
    }

    
    Write-Host ("INFO: Finished conversion for cmn_department to DWAPI format.")
    Return ,$dataTable
}

function Convert-DwAPILocationFromServiceNowCMN_Location {
    [OutputType([System.Data.DataTable])]                                                                                                                                                                   
    Param(
        [Parameter(Mandatory=$True)]
        [System.Data.DataTable] $ServiceNowDataTable,
        [Parameter(Mandatory=$false)]
        [System.Data.DataTable] $UserDataTable,
        [Parameter(Mandatory=$false)]
        [string] $UserFeedId = 1,
        [System.Data.DataTable] $DeviceDataTable,
        [Parameter(Mandatory=$false)]
        [string] $DeviceFeedId = 1
    )
    
    <#
    .Synopsis
    Return a datatable in the DWAPI location data format from the Get-ServiceNowTable for cmn_location

    .Description
    Takes in a datatable returned from the Get-ServiceNowTable and strips the fields required for insertion into the Dashworks location API.

    .Parameter ServiceNowDataTable
    A System.Data.DataTable object returned from the Get-ServiceNowTable function

    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema as used in the DW Users API calls populated with the provided data from serviceNow cmn_location.

    .Example
    # Convert the data for use in the DWAPI
    $dtDashworksInput = Convert-DwAPIlocationFromServiceNowCMN_location -SerivceNowDataTable $dtlocation
    #>
    Write-Host ("INFO: Starting conversion for cmn_location to DWAPI format.")

    $dataTable = New-Object System.Data.DataTable
    $dataTable.Columns.Add("uniqueIdentifier", [string]) | Out-Null
    $dataTable.Columns.Add("name", [string]) | Out-Null
    $dataTable.Columns.Add("region", [string]) | Out-Null
    $dataTable.Columns.Add("country", [string]) | Out-Null
    $dataTable.Columns.Add("state", [string]) | Out-Null
    $dataTable.Columns.Add("city", [string]) | Out-Null
    $dataTable.Columns.Add("buildingName", [string]) | Out-Null
    $dataTable.Columns.Add("address1", [string]) | Out-Null
    $dataTable.Columns.Add("address2", [string]) | Out-Null
    $dataTable.Columns.Add("address3", [string]) | Out-Null
    $dataTable.Columns.Add("address4", [string]) | Out-Null
    $dataTable.Columns.Add("postalCode", [string]) | Out-Null
    $dataTable.Columns.Add("floor", [string]) | Out-Null
    $dataTable.Columns.Add("users", [array]) | Out-Null
    $dataTable.Columns.Add("devices", [array]) | Out-Null

    foreach ($Row in $ServiceNowDataTable) {

        $NewRow = $null
        $NewRow = $dataTable.NewRow()
        $NewRow.uniqueIdentifier = $Row.sys_id
        $NewRow.name = $Row.name
        #$NewRow.region = $Row
        $NewRow.country = $Row.country
        $NewRow.state = $Row.state
        $NewRow.city = $Row.city
        #$NewRow.buildingName = $Row.name
        $NewRow.address1 = $Row.street
        #$NewRow.address2 = $Row.name
        #$NewRow.address3 = $Row.name
        #$NewRow.address4 = $Row.name
        $NewRow.postalCode = $Row.zip
        #$NewRow.floor = $Row.
        $AddUsers = @()
        
        if ($UserDataTable -and $UserFeedId) {
            foreach ($user in $UserDataTable.Select("location_link='$($row.sys_id)'")) {
                $username = ("/imports/users/{0}/items/{1}" -f $UserFeedId, $user.user_name)
                $AddUsers += $username
            }
        }
        $NewRow.users = $AddUsers

        $AddDevices = @()
        if ($DeviceDataTable -and $DeviceFeedId) {
            foreach ($device in $DeviceDataTable.Select("location_link='$($row.sys_id)'")) {
                $devicelink = ("/imports/devices/{0}/items/{1}" -f $DeviceFeedId, $device.sys_id)
                $AddDevices += $devicelink
            }
        }
        $NewRow.devices = $AddDevices
        $dataTable.Rows.Add($NewRow)
    }
    
    Write-Host ("INFO: Finished conversion for cmn_location to DWAPI format.")
    Return ,$dataTable
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
        [parameter(Mandatory=$False)]
        [array]$CustomFields = @()
    )


    if (-not $ImportId)
    {
        if (-not $FeedName)
        {
            return 'Device feed not found by name or ID'
        }

        $ImportId = (Get-JuribaImportDeviceFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName).id

        if (-not $ImportId)
        {
            return 'Device feed not found by name or ID'
        } else {
            
            $Deleteheaders = @{
                                "X-API-KEY" = "$APIKey"
                            }
            $Deleteuri = "{0}/apiv2/imports/devices/{1}/items" -f $Instance, $ImportId
            Invoke-RestMethod -Headers $Deleteheaders -Uri $Deleteuri -Method Delete| out-null

            Write-Host ("INFO: Deleted records for ImportID $ImportID, $Feedname")
        }
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = "{0}/apiv2/imports/devices/{1}/items" -f $Instance, $ImportId
    $ExcludeProperty = @("ItemArray", "Table", "RowError", "RowState", "HasErrors")
    if ($CustomFields.count -gt 0) {$ExcludeProperty += $CustomFields}

    $DWDeviceDataTable | ForEach-Object -Parallel {
    #foreach($Row in $DWDeviceDataTable){
        $row = $_

        #Write-Progress -Activity Uploading -Status "Writing Device Feed Object $RowCount" -PercentComplete (100 * ($RowCount / $Using:DWDeviceDataTable.Rows.Count))

        $Body = $null
        $Body = $Row | Select-Object *,CustomFieldValues -ExcludeProperty $using:ExcludeProperty
        
        $CustomFieldValues = @()       
        $CFVtemplate = 'if ($Row.### -ne [dbnull]::value)
                        {
                            $CustomField = @{
                                name = "###"
                                value = $Row.###
                            }
                            $CustomField
                        }'

        foreach($CustomFieldName in $using:CustomFields)
        {
            $ScriptBlock = $null
            $ScriptBlock=$CFVtemplate.Replace('###',$CustomFieldName)
            $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)
            $CustomFieldValues += & $ScriptBlock
        }
        $Body.CustomFieldValues = $CustomFieldValues
        $JSONBody = $Body | ConvertTo-Json
        $ByteArrayBody = [System.Text.Encoding]::UTF8.GetBytes($JSONBody)
        Invoke-RestMethod -Headers $Using:Postheaders -Uri $Using:uri -Method Post -Body $ByteArrayBody -AllowInsecureRedirect -MaximumRetryCount 5 -RetryIntervalSec 20 | out-null
        #Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $ByteArrayBody -MaximumRetryCount 5 -RetryIntervalSec 20 | out-null


        #$RowCount++
    } -ThrottleLimit 25

    Return ("{0} devices sent" -f $DWDeviceDataTable.Rows.Count)
}
function Invoke-DwBulkImportDeviceFeedDataTable{
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
        [parameter(Mandatory=$False)]
        [array]$CustomFields = @(),
        [parameter(Mandatory=$False)]
        [int]$BatchSize = 500
    )


    if (-not $ImportId)
    {
        if (-not $FeedName)
        {
            return 'Device feed not found by name or ID'
        }

        $ImportId = (Get-JuribaImportDeviceFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName).id

        if (-not $ImportId)
        {
            return 'Device feed not found by name or ID'
        } else {
            
            $Deleteheaders = @{
                                "X-API-KEY" = "$APIKey"
                            }
            $Deleteuri = "{0}/apiv2/imports/devices/{1}/items" -f $Instance, $ImportId
            Invoke-RestMethod -Headers $Deleteheaders -Uri $Deleteuri -Method Delete| out-null

            Write-Host ("$(get-date -format 'o'):INFO: Deleted records for ImportID $ImportID, $Feedname")
        }
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = '{0}/apiv2/imports/devices/{1}/items/$bulk' -f $Instance, $ImportId
    $ExcludeProperty = @("ItemArray", "Table", "RowError", "RowState", "HasErrors")
    if ($CustomFields.count -gt 0) {$ExcludeProperty += $CustomFields}

    $BulkUploadObject = @()
    $RowCount = 0
    foreach($Row in $DWDeviceDataTable){
        $RowCount++
        
        $Body = $null
        $Body = $Row | Select-Object *,CustomFieldValues -ExcludeProperty $ExcludeProperty
        
        $CustomFieldValues = @()       
        $CFVtemplate = 'if ($Row.### -ne [dbnull]::value)
                        {
                            $CustomField = @{
                                name = "###"
                                value = $Row.###
                            }
                            $CustomField
                        }'

        foreach($CustomFieldName in $CustomFields)
        {
            $ScriptBlock = $null
            $ScriptBlock=$CFVtemplate.Replace('###',$CustomFieldName)
            $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)
            $CustomFieldValues += & $ScriptBlock
        }
        $Body.CustomFieldValues = $CustomFieldValues

        $BulkUploadObject += $Body

        if ($BulkUploadObject.Count -eq $BatchSize -or $RowCount -eq $DWDeviceDataTable.Rows.Count)
        {
            $JSONBody = $BulkUploadObject | ConvertTo-Json -Depth 10
            $ByteArrayBody = [System.Text.Encoding]::UTF8.GetBytes($JSONBody)
            try{
                $dummy = Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $ByteArrayBody -MaximumRetryCount 3 -RetryIntervalSec 20
                write-debug "$(Get-date -Format 'o'):$RowCount rows processed"
            }catch{
                $timeNow = (Get-date -Format 'o')
                write-error "$timeNow;$_"
            }
            $BulkUploadObject = @()
        }
    }
    Return ("{0} devices sent" -f $DWDeviceDataTable.Rows.Count)
}
function Invoke-DwImportUserFeedDataTable{
    <#
    .Synopsis
    Loops a correctly formatted data table inserting all of the rows it contains.

    .Description
    Takes a System.Data.Datatable object with the columns required for the DwAPI user. Inserts these users one at a time.

    .Parameter Instance
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for and used.

    .Parameter ImportId
    The id of the user feed to be used.

    .Parameter DWDataTable
    [System.Data.DataTable] Data table containing the fields required to insert data into the DW user API.

    .Outputs
    Output type [string]
    Text confirming the number of rows to be inserted.

    .Example
    # Get the user feed id for the named feed.
    Write-UserFeedData -Instance $Instance -DWDataTable $dtDashworksInput -ImportId $userImportID -APIKey $APIKey
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
        [string]$ImportId,

        [parameter(Mandatory=$False)]
        [array]$CustomFields = @()
    )


    if (-not $ImportId)
    {
        if (-not $FeedName)
        {
            return 'User feed not found by name or ID'
        }

        $ImportId = (Get-JuribaImportUserFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName).id

        if (-not $ImportId)
        {
            return 'User feed not found by name or ID'
        } else {
            
            $Deleteheaders = @{
                                "X-API-KEY" = "$APIKey"
                            }
            $Deleteuri = "{0}/apiv2/imports/users/{1}/items" -f $Instance, $ImportId
            Invoke-RestMethod -Headers $Deleteheaders -Uri $Deleteuri -Method Delete | out-null

            Write-Host ("INFO: Deleted records for ImportID $ImportID, $Feedname")
        }
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = "{0}/apiv2/imports/users/{1}/items" -f $Instance, $ImportId
    $ExcludeProperty = @("ItemArray", "Table", "RowError", "RowState", "HasErrors")
    if ($CustomFields.count -gt 0) {$ExcludeProperty += $CustomFields}

    $threadSafeDictionary = [System.Collections.Concurrent.ConcurrentDictionary[string,object]]::new()
    $DWUserDataTable | Foreach-Object -Parallel {
    #foreach($Row in $DWUserDataTable){
        $Row = $_
        $dict = $using:threadSafeDictionary
        #Write-Progress -Activity Uploading -Status "Writing User Feed Object $RowCount" -PercentComplete (100 * ($RowCount / $Using:DWUserDataTable.Rows.Count))
        $Body = $null
        $Body = $Row | Select-Object *,CustomFieldValues -ExcludeProperty $using:ExcludeProperty
        
        $CustomFieldValues = @()       
        $CFVtemplate = 'if ($Row.### -ne [dbnull]::value)
                        {
                            $CustomField = @{
                                name = "###"
                                value = $Row.###
                            }
                            $CustomField
                        }'

        foreach($CustomFieldName in $using:CustomFields)
        {
            $ScriptBlock = $null
            $ScriptBlock = $CFVtemplate.Replace('###',$CustomFieldName)
            $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)
            $CustomFieldValues += & $ScriptBlock
        }
        $Body.CustomFieldValues = $CustomFieldValues
        $JSONBody = $Body | ConvertTo-Json
        $ByteArrayBody = [System.Text.Encoding]::UTF8.GetBytes($JSONBody)
        try{
            Invoke-RestMethod -Headers $using:Postheaders -Uri $using:uri -Method Post -Body $ByteArrayBody -AllowInsecureRedirect -MaximumRetryCount 5 -RetryIntervalSec 20 | out-null
        }catch{
            $timeNow = (Get-date -Format 'o')
            $errorMessage = $_
            $dict.TryAdd($Row.username,"$timeNow;$errorMessage") | Out-Null
        }
        #Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $ByteArrayBody | out-null
    } -ThrottleLimit 25

    if ($threadSafeDictionary.count -gt 0)
    {
        Write-Debug "User upload failed $($threadSafeDictionary.count) times"
    }
    write-debug "$($DWUserDataTable.Rows.Count - $threadSafeDictionary.count) users sent"

    Return $threadSafeDictionary
}
function Invoke-DwBulkImportUserFeedDataTable{
    <#
    .Synopsis
    Loops a correctly formatted data table inserting all of the rows it contains.

    .Description
    Takes a System.Data.Datatable object with the columns required for the DwAPI user. Inserts these users one at a time.

    .Parameter Instance
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for and used.

    .Parameter ImportId
    The id of the user feed to be used.

    .Parameter DWDataTable
    [System.Data.DataTable] Data table containing the fields required to insert data into the DW user API.

    .Outputs
    Output type [string]
    Text confirming the number of rows to be inserted.

    .Example
    # Get the user feed id for the named feed.
    Write-UserFeedData -Instance $Instance -DWDataTable $dtDashworksInput -ImportId $userImportID -APIKey $APIKey
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
        [string]$ImportId,

        [parameter(Mandatory=$False)]
        [array]$CustomFields = @(),

        [parameter(Mandatory=$False)]
        [int]$BatchSize = 500
    )


    if (-not $ImportId)
    {
        if (-not $FeedName)
        {
            return 'User feed not found by name or ID'
        }

        $ImportId = (Get-JuribaImportUserFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName).id

        if (-not $ImportId)
        {
            return 'User feed not found by name or ID'
        } else {
            
            $Deleteheaders = @{
                                "X-API-KEY" = "$APIKey"
                            }
            $Deleteuri = "{0}/apiv2/imports/users/{1}/items" -f $Instance, $ImportId
            Invoke-RestMethod -Headers $Deleteheaders -Uri $Deleteuri -Method Delete | out-null

            Write-Host ("$(get-date -format 'o'):INFO: Deleted records for ImportID $ImportID, $Feedname")
        }
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = '{0}/apiv2/imports/users/{1}/items/$bulk' -f $Instance, $ImportId
    $ExcludeProperty = @("ItemArray", "Table", "RowError", "RowState", "HasErrors")
    if ($CustomFields.count -gt 0) {$ExcludeProperty += $CustomFields}

    $BulkUploadObject = @()
    $RowCount = 0
    foreach($Row in $DWUserDataTable.Rows){
        $RowCount++
        $Body = $null
        $Body = $Row | Select-Object *,CustomFieldValues -ExcludeProperty $ExcludeProperty
        
        $CustomFieldValues = @()       
        $CFVtemplate = 'if ($Row.### -ne [dbnull]::value)
                        {
                            $CustomField = @{
                                name = "###"
                                value = $Row.###
                            }
                            $CustomField
                        }'

        foreach($CustomFieldName in $CustomFields)
        {
            $ScriptBlock = $null
            $ScriptBlock = $CFVtemplate.Replace('###',$CustomFieldName)
            $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)
            $CustomFieldValues += & $ScriptBlock
        }
        $Body.CustomFieldValues = $CustomFieldValues

        $BulkUploadObject += $Body

        if ($BulkUploadObject.Count -eq $BatchSize -or $RowCount -eq $DWUserDataTable.Rows.Count)
        {
            $JSONBody = $BulkUploadObject | ConvertTo-Json -Depth 10
            $ByteArrayBody = [System.Text.Encoding]::UTF8.GetBytes($JSONBody)
            try{
                $dummy = Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $ByteArrayBody -MaximumRetryCount 3 -RetryIntervalSec 20
                write-debug "$(Get-date -Format 'o'):$RowCount rows processed"
            }catch{
                $timeNow = (Get-date -Format 'o')
                write-error "$timeNow;$_"
            }
            $BulkUploadObject = @()
        }
    }
    Return $threadSafeDictionary
}

function Invoke-DwImportDepartmentFeedDataTable{
    <#
    .Synopsis
    Loops a correctly formatted data table inserting all of the rows it contains.

    .Description
    Takes a System.Data.Datatable object with the columns required for the DwAPI user. Inserts these users one at a time.

    .Parameter Instance
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for and used.

    .Parameter ImportId
    The id of the user feed to be used.

    .Parameter DWDataTable
    [System.Data.DataTable] Data table containing the fields required to insert data into the DW user API.

    .Outputs
    Output type [string]
    Text confirming the number of rows to be inserted.
    #>

    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,

        [Parameter(Mandatory=$True)]
        [System.Data.DataTable]$DWDepartmentDataTable,

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
            return 'Department feed not found by name or ID'
        }

        $ImportId = (Get-JuribaImportDepartmentFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName).id

        if (-not $ImportId)
        {
            return 'Department feed not found by name or ID'
        } else {
            
            $Deleteheaders = @{
                                "X-API-KEY" = "$APIKey"
                            }
            $Deleteuri = "{0}/apiv2/imports/departments/{1}/items" -f $Instance, $ImportId
            Invoke-RestMethod -Headers $Deleteheaders -Uri $Deleteuri -Method DELETE | out-null

            Write-Host ("INFO: Deleted records for ImportID $ImportID, $Feedname")
        }
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = "{0}/apiv2/imports/departments/{1}/items" -f $Instance, $ImportId

    $DWDepartmentDataTable | Foreach-Object -Parallel {
        $Row = $_
        #Write-Progress -Activity Uploading -Status "Writing User Feed Object $RowCount" -PercentComplete (100 * ($RowCount / $Using:DWUserDataTable.Rows.Count))

        $Body = $null
        $Body = $Row | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
        # Replace non-printable characters
        $Body = $Body -creplace '\P{IsBasicLatin}'
        try{
            Invoke-RestMethod -Headers $Using:Postheaders -Uri $Using:uri -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($Body)) -AllowInsecureRedirect | out-null
        }catch{
            write-output "Error row sysid $($row.uniqueIdentifier) : $body"
        }

        #$RowCount++
    } -ThrottleLimit 25

    Return ("{0} departments sent" -f $DWDepartmentDataTable.Rows.Count)
}
function Invoke-DwImportLocationFeedDataTable{
    <#
    .Synopsis
    Loops a correctly formatted data table inserting all of the rows it contains.

    .Description
    Takes a System.Data.Datatable object with the columns required for the DwAPI user. Inserts these users one at a time.

    .Parameter Instance
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for and used.

    .Parameter ImportId
    The id of the user feed to be used.

    .Parameter DWDataTable
    [System.Data.DataTable] Data table containing the fields required to insert data into the DW user API.

    .Outputs
    Output type [string]
    Text confirming the number of rows to be inserted.
    #>

    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,

        [Parameter(Mandatory=$True)]
        [System.Data.DataTable]$DWLocationDataTable,

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
            return 'Location feed not found by name or ID'
        }

        $ImportId = (Get-JuribaImportLocationFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName).id

        if (-not $ImportId)
        {
            return 'Location feed not found by name or ID'
        } else {
            
            $Deleteheaders = @{
                                "X-API-KEY" = "$APIKey"
                            }
            $Deleteuri = "{0}/apiv2/imports/locations/{1}/items" -f $Instance, $ImportId
            Invoke-RestMethod -Headers $Deleteheaders -Uri $Deleteuri -Method DELETE | out-null

            Write-Host ("INFO: Deleted records for ImportID $ImportID, $Feedname")
        }
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = "{0}/apiv2/imports/locations/{1}/items" -f $Instance, $ImportId

    #$DWLocationDataTable | Foreach-Object -Parallel {
    #    $Row = $_
    foreach($Row in $DWLocationDataTable) {

        $Body = $null
        $Body = $Row | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
        #try{
            #Invoke-RestMethod -Headers $Using:Postheaders -Uri $Using:uri -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($Body)) | out-null
            Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($Body)) -AllowInsecureRedirect | out-null
        #}
        #catch{write-host "Location $($Row.uniqueIdentifier) Failed with Error: $($_.ErrorDetails)"}
        #$RowCount++
    }# -ThrottleLimit 25

    Return ("{0} locations sent" -f $DWLocationDataTable.Rows.Count)
}

function Start-JPLog {
    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,

        [Parameter(Mandatory=$True)]
        [string]$APIKey
    )
    $Headers = @{"accept" = "application/json";"X-API-KEY" = $APIKey;"Content-Type"="application/json"}
    Invoke-webrequest -uri "$($Instance)/apiv2/event-logs/start-event-logging-command" -Method Post -Headers $Headers -Body "{""ServiceId"": 19}" -AllowInsecureRedirect | Out-Null
}

function Add-JPLogMessage {
    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,
        [Parameter(Mandatory=$True)]
        [string]$APIKey,
        [parameter(Mandatory=$True)]
        [ValidateSet('Noise','Debug','Info','Warning','Error','Fatal')]
        [string]$Priority,
        [Parameter(Mandatory=$True)]
        [string]$Message
    )
    $Headers = @{"accept" = "application/json";"X-API-KEY" = $APIKey;"Content-Type"="application/json"}
    $body = @{"message"=$Message;"source"="Import Script";"level"=$Priority} | ConvertTo-Json
    Invoke-webrequest -uri "$($Instance)/apiv2/event-logs" -Method Post -Headers $Headers -Body $Body -AllowInsecureRedirect | Out-Null
}

function Close-JPLog {
    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,

        [Parameter(Mandatory=$True)]
        [string]$APIKey
    )
    $Headers = @{"accept" = "application/json";"X-API-KEY" = $APIKey;"Content-Type"="application/json"}
    Invoke-webrequest -uri "$($Instance)/apiv2/event-logs/stop-event-logging-command" -Method Post -Headers $Headers -AllowInsecureRedirect | Out-Null
}

#Declare input parameters. 
$serviceNowAuth = @{
    AuthType = "OAuth"
    Server   = "$Env:AtosServiceNowServer"
    Credential = New-Object System.Management.Automation.PSCredential ("$Env:AtosServiceNowUsername", $(ConvertTo-SecureString "$Env:AtosServiceNowPassword" -AsPlainText -Force))
    ClientID = "$Env:AtosServiceNowClientID"
    ClientSecret = "$Env:AtosServiceNowClientSecret"
}
$DwParams = @{
    Instance = "$Env:JuribaPlatformInstance"
    APIKey = "$Env:JuribaPlatformAPIKey"
}

$ServiceNowFilter = "$Env:AtosServiceNowDomainFilter"
$DeviceFeedName ="ServiceNow Hardware"
$DeviceFeedId = (Get-JuribaImportDeviceFeed @DwParams -Name $DeviceFeedName).id
$UserFeedName ="ServiceNow Users"
$UserFeedId = (Get-JuribaImportUserFeed @DwParams -Name $UserFeedName).id
$DepartmentFeedName = "ServiceNow Department"
$LocationFeedName = "ServiceNow Location"
$ETLName = 'Dashworks ETL (Transform Only)'
$JPHeaders = @{"accept" = "application/json";"X-API-KEY" = $($DwParams.APIKey);"Content-Type"="application/json"}

## Start a logging session with the server
Start-JPLog @DwParams

# Log the source system
Add-JPLogMessage @DwParams -Priority Info -Message "Client Target System: $($serviceNowAuth.Server)"

# Get service now bearer token
[PSObject]$OAuthToken = Get-ServiceNowToken @serviceNowAuth
# Log the a bearer token has been retrieved
if ($OAuthToken.AuthHeader.Length -gt 7)
{
    Add-JPLogMessage @DwParams -Priority Info -Message "Authentication Credentials Passed - Bearer token in use"
} else {
    Add-JPLogMessage @DwParams -Priority Error -Message "Authentication Credentials Failed for Source: $($serviceNowAuth.Server)"
    Close-JPLog @DWParams
    break
}

#Get Data Import Counts
$InitialDataFeeds = (Invoke-RestMethod -uri "$($DWParams.Instance)/apiv1/admin/data-imports" -Method Get -Headers $JPHeaders) | Where-Object{$_.name -eq $DeviceFeedName -or $_.name -eq $UserFeedName -or $_.name -eq $DepartmentFeedName -or $_.name -eq $LocationFeedName}

#Pull and merge data from servicenow
Write-Debug "$(get-date -format 'o'):Start data retrieval"
Add-JPLogMessage @DwParams -Priority Info -Message "Start data retrieval"

$SNTables = @('alm_asset','sys_user','cmdb_ci_computer','cmn_location','alm_stockroom')

foreach($table in $SNTables)
{
    Add-JPLogMessage @DwParams -Priority Info -Message "Pulling table $table"
    $ScriptBlock = $null
    $ScriptBlock = '$' + $table + ' = Get-ServiceNowTable -AuthToken $OAuthToken -tableName ''' + $table + ''' -NameValuePairs $ServiceNowFilter;' + "`n"
    $ScriptBlock += 'Add-JPLogMessage @DwParams -Priority Info -Message "$table pull complete: $($' + $table + '.Rows.Count) rows";' + "`n"
    $ScriptBlock += 'Write-Debug "$(get-date -format ''o''):$table pull complete: $($' + $table + '.Rows.Count) rows";' + "`n"
    $ScriptBlock += '@(,$' + $table + ')' #Return the table
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)
    Set-Variable -Name $table -Value (& $ScriptBlock)
}

Write-Debug "$(get-date -format 'o'):Starting data manipulation"
Add-JPLogMessage @DwParams -Priority Info -Message "Starting data table merge"

$alm_asset_user_merge = Merge-ServiceNowTable -primaryTable $alm_asset -secondaryTable $sys_user -LeftjoinKeyProperty "assigned_to_link" -rightjoinkeyproperty "sys_id" -AddColumn @{"user_name"="user_name";"location_link"="user_location_link"}
$alm_asset_computer_merge = Merge-ServiceNowTable -primaryTable $alm_asset_user_merge -secondaryTable $cmdb_ci_computer -LeftjoinKeyProperty "ci_link" -rightjoinkeyproperty "sys_id" -AddColumns @{"os"="os";"os_version"="os_version";"os_service_pack"="os_service_pack";"manufacturer"="manufacturer";"form_factor"="form_factor";"virtual"="virtual";"cpu_count"="cpu_count";"cpu_speed"="cpu_speed";"cpu_type"="cpu_type";"disk_space"="disk_space";"ram"="ram"}
$alm_asset_computer_merge = Merge-ServiceNowTable -primaryTable $alm_asset_computer_merge -secondaryTable $cmn_location -LeftjoinKeyProperty "user_location_link" -rightjoinkeyproperty "sys_id" -AddColumns @{"parent"="parent";"parent_link"="parent_link";"country"="country";"city"="city";"name"="building"}
$alm_asset_computer_merge = Merge-ServiceNowTable -primaryTable $alm_asset_computer_merge -secondaryTable $alm_stockroom -LeftjoinKeyProperty "parent_link" -rightjoinkeyproperty "location_link" -AddColumns @{"name"="stockroom";"u_correlation_id"="stockroom_link"}

#Convert data into the Juriba Platform APIv2 Schema.
Write-Debug "$(get-date -format 'o'):Start data conversion" 
Add-JPLogMessage @DwParams -Priority Info -Message "Starting data conversion"
#$dtDeviceAPIInput = Convert-DwAPIDeviceFromServiceNowCMDB_CI_Computer -ServiceNowDataTable $CMDB_CI_Data_merge -UserFeedId $UserFeedId
$dtDeviceAPIInput = Convert-DwAPIDeviceFromServiceNowAlm_Asset -ServiceNowDataTable $alm_asset_computer_merge -UserFeedId $UserFeedId -CustomFields @{'install_status'='install_status';'device_sysid'='u_correlation_id';'targetdevice'='u_remuneration';'stockroom'='stockroom';'country'='country';'city'='city';'building'='building';'parent'='parent';'today_fr_static'=$((get-date).ToString('dd MMMM yyyy', [CultureInfo]'fr-fr'));'today_en_static'=$((get-date).ToString('MMMM dd, yyyy', [CultureInfo]'en-us'))}
$dtUserAPIInput = Convert-DwAPIUserFromServiceNowSys_User -ServiceNowDataTable $sys_user -CustomFields @{'mobile_phone' = 'mobile_phone';'phone' = 'phone';'location_sysid' = 'location_link';'user_sysid' = 'sys_id'}
#$dtDepartmentAPIInput = Convert-DwAPIDeptFromServiceNowCMN_Department -ServiceNowDataTable $cmn_deptartment -UserDataTable $sys_user -UserFeedId $UserFeedId
$dtDepartmentAPIInput = Convert-DwAPIDeptFromServiceNowSys_User -UserDataTable $sys_user -UserFeedId $UserFeedId
$dtLocationAPIInput = Convert-DwAPILocationFromServiceNowCMN_Location -ServiceNowDataTable $cmn_location -UserDataTable $sys_user -UserFeedId $UserFeedId -DeviceDataTable $alm_asset -DeviceFeedID $DeviceFeedID

Write-Debug "$(get-date -format 'o'):Start data upload"
Add-JPLogMessage @DwParams -Priority Info -Message "Starting data upload"
#Insert into Juriba.Platform
$UploadFailures = Invoke-DwBulkImportUserFeedDataTable @DwParams -DWUserDataTable $dtUserAPIInput -FeedName $UserFeedName -CustomFields @('mobile_phone','phone','location_sysid','user_sysid')
Write-Debug "$(get-date -format 'o'):User Upload Complete"
Add-JPLogMessage @DwParams -Priority Info -Message "User Upload Complete"
Invoke-DwBulkImportDeviceFeedDataTable @DwParams -DWDeviceDataTable $dtDeviceAPIInput -FeedName $DeviceFeedName -CustomFields @('install_status','device_sysid','targetdevice','stockroom','country','city','building','parent','today_fr_static','today_en_static')
Write-Debug "$(get-date -format 'o'):Device Upload Complete"
Add-JPLogMessage @DwParams -Priority Info -Message "Device Upload Complete"
Invoke-DwImportDepartmentFeedDataTable @DwParams -DWDepartmentDataTable $dtDepartmentAPIInput -FeedName $DepartmentFeedName
Write-Debug "$(get-date -format 'o'):Department Upload Complete"
Add-JPLogMessage @DwParams -Priority Info -Message "Department Upload Complete"
Invoke-DwImportLocationFeedDataTable @DwParams -DWLocationDataTable $dtLocationAPIInput -FeedName $LocationFeedName
Write-Debug "$(get-date -format 'o'):Location Upload Complete"
Add-JPLogMessage @DwParams -Priority Info -Message "Location Upload Complete"

Write-Debug ("$(get-date -format 'o'):INFO: Import finished.")
Add-JPLogMessage @DwParams -Priority Info -Message "Data Import Complete: Checking import counts"

$FinalDataFeeds = (Invoke-RestMethod -uri "$($DWParams.Instance)/apiv1/admin/data-imports" -Method Get -Headers $JPHeaders) | Where-Object{$_.name -eq $DeviceFeedName -or $_.name -eq $UserFeedName -or $_.name -eq $DepartmentFeedName -or $_.name -eq $LocationFeedName}
$DataCheckComplete = $true
foreach($DataFeed in $FinalDataFeeds)
{
    $ObjectCount = 0
    $InitialObjectCount = 0
    $ObjectCount = $DataFeed.ObjectsCount
    $InitialObjectCount = (($InitialDataFeeds) | Where-Object{$_.name -eq $DataFeed.name}).objectscount
    Write-Debug "$($DataFeed.name) data change: $($ObjectCount - $InitialObjectCount) rows."
    Add-JPLogMessage @DwParams -Priority Info -Message "$($DataFeed.name) data change: $($ObjectCount - $InitialObjectCount) rows."
    if ([Math]::Abs($ObjectCount - $InitialObjectCount)/($InitialObjectCount + 1)*100 -gt 5) #5% row count change
    {
        $DataCheckComplete = $false
    }
}

if ($DataCheckComplete) {
    #Trigger ETL
    $uri = "{0}/apiv2/etl-jobs" -f $DWParams.Instance
    $ETLJobs = Invoke-RestMethod -Headers $JPHeaders -Uri $uri -Method Get -AllowInsecureRedirect
    $ETLID = ($ETLJobs | where-object {$_.name -eq $ETLName}).id
    $uri = "{0}/apiv2/etl-jobs/{1}" -f $DWParams.Instance,$ETLID
    Invoke-RestMethod -Headers $JPHeaders -Uri $uri -Method Post -AllowInsecureRedirect | out-null

    $currentUTCtime = (Get-Date).ToUniversalTime()
    # Write an information log with the current time.
    Write-Debug "ETL Triggered at $currentUTCtime."
    Add-JPLogMessage @DwParams -Priority Info -Message "ETL Triggered at $currentUTCtime."
} else {
    Add-JPLogMessage @DwParams -Priority Error -Message "Data Check Failed. ETL not launched."
	#To do: Raise Jira JRB for failed Data Feed Refresh
}

Close-JPLog @DWParams