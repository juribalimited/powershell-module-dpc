<#
    .SYNOPSIS
    Import Devices From ServiceNow into a Dashworks Device Feed.

    .DESCRIPTION
    Pulls device hardware information from ServiceNow into a SQLite database and then queries this data to return a dataset
    which is then injected into a Dashworks device feed.

    The usernames, passwords and server locations are pulled from a table in the database.

    To populate the data table with the details, use the Create_SQLiteSettings_DB.ps1 script.

    Uses the supplied .\System.Data.SQLite.dll which requires .Net 4.6. This can be changed to suit.
    Alternate versions can be found at https://system.data.sqlite.org/

#>

function Log {
    param (
        [string]$Message
        )
    $Message = ("{0} {1} {2}" -f (Get-Date -UFormat "%Y-%m-%d"), (Get-Date -UFormat "%T"), $Message)
    Write-Host $Message
    $Message | Out-File -FilePath $global:logfile -Append
}

function Get-ServiceNowOAuthTokenSQLite {
param (
        [Parameter(Mandatory=$true)][string] $DBPath,
        [Parameter(Mandatory=$true)][string] $DLLPath
    )

    Add-Type -Path $DLLPath

    $con = New-Object -TypeName System.Data.SQLite.SQLiteConnection
    $con.ConnectionString = "Data Source=$DBPath"
    $con.Open()


    $sql = $con.CreateCommand()
    $sql.CommandText = "SELECT * FROM APICredentials WHERE FriendlyName='ServiceNow'"
    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
    $dtCreds = New-Object System.Data.DataTable
    [void]$adapter.Fill($dtCreds)

    $Reply = New-Object -TypeName PSCustomObject    

    if ($dtCreds.Rows.Count -eq 0)
    {
        write-error "No ServiceNow connection details found"
        return $Reply
    }
    
    if ($dtCreds.Rows[0].AuthType -eq '102')
    {


        $pair = "{0}:{1}" -f $dtCreds.Rows[0].Username, $dtCreds.Rows[0].Password
		$bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $basicAuthValue = "Basic $base64"
		
		#Add the properties to the OAuth return object so that they can be checked later.
		$Reply | Add-Member -NotePropertyName ServerURL -NotePropertyValue $dtCreds.Rows[0].Server
		$Reply | Add-Member -NotePropertyName AuthHeader -NotePropertyValue $basicAuthValue

    }else{

        $tokenValid = $dtCreds.Rows[0].AccessToken -ne [DBNull]::Value -and (Get-date $dtCreds.Rows[0].AccessTokenExpires) -gt (Get-date).AddMinutes(10)
        $canRefreshToken = $dtCreds.Rows[0].RefreshToken -ne [DBNull]::Value -and (Get-date $dtCreds.Rows[0].RefreshTokenExpires) -gt (Get-date)

        if ($tokenValid)
        {
            write-debug "Auth Token Valid"
            $Reply = New-Object -TypeName PSCustomObject
            $Reply | Add-Member -NotePropertyName access_token -NotePropertyValue $dtCreds.Rows[0].AccessToken
            $Reply | Add-Member -NotePropertyName refresh_token -NotePropertyValue $dtCreds.Rows[0].RefreshToken
            $Reply | Add-Member -NotePropertyName scope -NotePropertyValue "useraccount"
            $Reply | Add-Member -NotePropertyName token_type -NotePropertyValue "Bearer"
            $Reply | Add-Member -NotePropertyName expires_in -NotePropertyValue "1799"
            $Reply | Add-Member -NotePropertyName expires -NotePropertyValue $dtCreds.Rows[0].AccessTokenExpires
            $Reply | Add-Member -NotePropertyName Clientid -NotePropertyValue $dtCreds.Rows[0].Clientid
            $Reply | Add-Member -NotePropertyName ClientSecret -NotePropertyValue $dtCreds.Rows[0].ClientSecret
            $Reply | Add-Member -NotePropertyName ServerURL -NotePropertyValue $dtCreds.Rows[0].Server
		    $Reply | Add-Member -NotePropertyName AuthHeader -NotePropertyValue "Bearer $($dtCreds.Rows[0].AccessToken)"
		    $Reply | Add-Member -NotePropertyName SyncTable -NotePropertyValue $dtCreds.Rows[0].SyncTable

        }elseif ($canRefreshToken)
        {
            $body = [System.Text.Encoding]::UTF8.GetBytes(‘grant_type=refresh_token&client_id=’+[uri]::EscapeDataString($dtCreds.Rows[0].ClientID)+’&client_secret=’+[uri]::EscapeDataString($dtCreds.Rows[0].ClientSecret)+’&refresh_token=’+[uri]::EscapeDataString($dtCreds.Rows[0].RefreshToken))
	        try{
		        $Reply = Invoke-RestMethod -Uri "$($dtCreds.Rows[0].server)/oauth_token.do" -Body $Body -ContentType ‘application/x-www-form-urlencoded’ -Method Post

		        if ($Reply.GetType().Name -eq 'string')
		        {
		            write-error 'Auth request returned a string. Please check host.'
		            $Reply = $null
		        }else{
		            #Add the properties to the OAuth return object so that they can be checked later.
		            $Reply | Add-Member -NotePropertyName expires -NotePropertyValue (get-date).AddSeconds($Reply.expires_in)
		            $Reply | Add-Member -NotePropertyName Clientid -NotePropertyValue $snClientid
		            $Reply | Add-Member -NotePropertyName ClientSecret -NotePropertyValue $snClientSecret
		            $Reply | Add-Member -NotePropertyName ServerURL -NotePropertyValue $dtCreds.Rows[0].Server
		            $Reply | Add-Member -NotePropertyName AuthHeader -NotePropertyValue "Bearer $($Reply.access_token)"
		            $Reply | Add-Member -NotePropertyName SyncTable -NotePropertyValue $dtCreds.Rows[0].SyncTable

		            $sql.CommandText = "UPDATE APICredentials SET AccessToken='{0}',AccessTokenExpires='{1}',RefreshToken='{2}',RefreshTokenExpires='{3}' WHERE FriendlyName='ServiceNow'" -f $Reply.access_token,$(get-date $Reply.expires -UFormat '+%Y-%m-%d %H:%M:%S'),$Reply.refresh_token,$(get-date (get-date).AddDays(100) -UFormat '+%Y-%m-%d %H:%M:%S')
		            $sql.ExecuteNonQuery()
		        }
		        write-output "Auth Token Refreshed - expires $($Reply.Expires)" 
	        }
	        catch{
		        write-error "Auth Token Refresh Failed - $_"
		        $canRefreshToken = $false
	        }
        }
        if (-not $canRefreshToken)
        {
            #Token doesn't exist or cannot be refreshed: Get a new token and store the values
            $body = [System.Text.Encoding]::UTF8.GetBytes(‘grant_type=password&username=’+[uri]::EscapeDataString($dtCreds.Rows[0].Username)+’&password=’+[uri]::EscapeDataString($dtCreds.Rows[0].Password)+’&client_id=’+[uri]::EscapeDataString($dtCreds.Rows[0].ClientID)+’&client_secret=’+[uri]::EscapeDataString($dtCreds.Rows[0].ClientSecret))

            $Reply = Invoke-RESTMethod -Method 'Post' -URI "$($dtCreds.Rows[0].server)/oauth_token.do" -body $Body -ContentType "application/x-www-form-urlencoded"

            if ($Reply.GetType().Name -eq 'string')
            {
                write-error 'Auth request returned a string. Please check host.'
                $Reply = $null
            }else{
                #Add the properties to the OAuth return object so that they can be checked later.
                $Reply | Add-Member -NotePropertyName expires -NotePropertyValue (get-date).AddSeconds($Reply.expires_in)
                $Reply | Add-Member -NotePropertyName Clientid -NotePropertyValue $dtCreds.Rows[0].Clientid
                $Reply | Add-Member -NotePropertyName ClientSecret -NotePropertyValue $dtCreds.Rows[0].ClientSecret
                $Reply | Add-Member -NotePropertyName ServerURL -NotePropertyValue $dtCreds.Rows[0].Server
		        $Reply | Add-Member -NotePropertyName AuthHeader -NotePropertyValue "Bearer $($Reply.access_token)"
		        $Reply | Add-Member -NotePropertyName SyncTable -NotePropertyValue $dtCreds.Rows[0].SyncTable

                # 100 days is added to the refresh token for its expiery as this is the default for servicenow.
                $sql.CommandText = "UPDATE APICredentials SET AccessToken='{0}',AccessTokenExpires='{1}',RefreshToken='{2}',RefreshTokenExpires='{3}' WHERE FriendlyName='ServiceNow'" -f $Reply.access_token,$(get-date $Reply.expires -UFormat '+%Y-%m-%d %H:%M:%S'),$Reply.refresh_token,$(get-date (get-date).AddDays(100) -UFormat '+%Y-%m-%d %H:%M:%S')
                $sql.ExecuteNonQuery()
            }
            write-output "New Auth Token Obtained - expires $($Reply.Expires)"
        }
    }

    $con.Close()

    return $Reply
}

function Get-ServiceNowTableSQLite {
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
    [Parameter(Mandatory=$true)][string] $DBPath,
    [Parameter(Mandatory=$true)][string] $DLLPath,
    [Parameter(Mandatory=$false)][string] $NameValuePairs,
    [Parameter(Mandatory=$false)][string] $ChunkSize = 5000,
    [Parameter(Mandatory=$false)][string] $UseOAuth = $true
    )

    Log ("INFO: Get-ServiceNowTable")
    Log ("INFO: Table Name: {0}" -f $tablename)
    Log ("INFO: Chunk Size: {0}" -f $ChunkSize)

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Add-Type -Path $DLLPath

    $con = New-Object -TypeName System.Data.SQLite.SQLiteConnection
    $con.ConnectionString = "Data Source=$DBPath"

    try{
        $con.Open()
    }catch{
        Log ("ERROR: No SQL connection")
        break;
    }

    $sqlcmd = $con.CreateCommand()
    $sqlcmd.CommandText = "SELECT AuthType FROM APICredentials WHERE FriendlyName='ServiceNow'"
    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sqlcmd
    $dtCreds = New-Object System.Data.DataTable
    [void]$adapter.Fill($dtCreds)


    # Set headers for ServiceNow Requests
    $headers = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
    $headers.Add('Accept','application/json')
    $headers.Add('Content-Type','application/json')

    # if ($UseOAuth)
    if ($dtCreds[0].AuthType -eq 101)
    {
        Log ("INFO: Using OAuth")
        $OAuth = Get-ServiceNowOAuthTokenSQLite -DBPath $DBPath -DLLPath $DLLPath
        $headers.Add('Authorization',('Bearer {0}' -f $OAuth.access_token))
        $ServerURL = $OAuth.ServerURL
    }
    elseif ($dtCreds[0].AuthType -eq 102)## basic auth
    {
        Log ("INFO: Basic Auth not implemented")
        break
    }

    $dtResults = New-Object System.Data.DataTable
    $sqlcmd.CommandText = "SELECT COUNT(*) TableFound FROM sqlite_master WHERE name='SN_$TableName'"
    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sqlcmd
    [void]$adapter.Fill($dtResults)

    if ($dtResults.Rows[0].TableFound -eq 0)
    {
        Log ("INFO: Database table doesn't exist.")
        #If the table doesn't exist, create it.

        # Specify HTTP method
        $method = 'Get'
        $offset=0
        $limit = 1

        $uri="$($ServerURL)/api/now/table/$TableName"+"?sysparm_limit={1}&sysparm_offset={0}" -f $offset, $limit
        Log ("INFO: URI: {0}" -f $uri)

        try{
            $pagedresponse = $null
            $pagedresponse = (Invoke-RestMethod -Headers $headers -Method $method -Uri $uri -ContentType 'application/json' -UseBasicParsing).result
        }catch{
            Log ("ERROR: Service Now request failed")
            Log ("ERROR: StatusCode: {0}" -f $_.Exception.Response.StatusCode.value__)
            Log ("ERROR: StatusDescription: {0}" -f $_.Exception.Response.StatusDescription)
            Log ("ERROR: Message: {0}" -f $_.Exception.Message)
        }

        if ($pagedresponse.Count -gt 0)
        {
            $CreateTableSQL = "`nCREATE TABLE ""SN_$TableName""`n("
            foreach($object_properties in $($pagedresponse | Get-Member | Where-Object{$_.MemberType -eq "NoteProperty"}))
            {
                # Access the name of the property
                $CreateTableSQL += "`n`t""" + $object_properties.Name + """ text,"
            }
            $CreateTableSQL = $CreateTableSQL.Substring(0,$CreateTableSQL.Length-1) + "`n)"

            Log ("INFO: Create table script: {0}" -f $CreateTableSQL)
            $sqlcmd.CommandText = $CreateTableSQL
            $sqlcmd.CommandType = [System.Data.CommandType]::Text
            $sqlcmd.ExecuteNonQuery()
        }
    }else{
        #Truncate data table?
        #$cmd.CommandText = "TRUNCATE TABLE Custom.dbo.SN_$TableName"
        Log ("INFO: Database table exists, delete existing data.")
        $sqlcmd.CommandText = "DELETE FROM SN_$TableName"
        Log ("INFO: Delete rows script: {0}" -f $sqlcmd.CommandText)
        $deletedrows = $sqlcmd.ExecuteNonQuery()
        Log ("INFO: Deleted {0} rows from SN_{1}" -f $deletedrows, $TableName)
    }
    
    # Pull the table data from the table in question.
    $method = 'Get'
    $response = $null
    $offset=0
    $limit = $ChunkSize
    $count=$limit

    while ($count -eq $limit)
    {
        #Check to see if the OAuth token is still going to be valid for the request. If not, get a new one.
        if ($dtCreds[0].AuthType -eq 101 -and $OAuth.expires -lt (Get-date).AddMinutes(10))
        {
            Log ("INFO: Token Expires at: {0}, current time: {1} - forcing new OAuth token" -f $OAuth.expires, (get-date))
            $OAuth = Get-ServiceNowOAuthTokenSQLite -DBPath $DBPath -DLLPath $DLLPath
            [void]$headers.Remove("Authorization")
            [void]$headers.Add("Authorization","Bearer "+$OAuth.access_token)
        }

        # Specify endpoint uri
        $uri="$($ServerURL)/api/now/table/$TableName"+"?sysparm_limit={1}&sysparm_offset={0}{2}" -f $offset, $limit, $NameValuePairs
        Log ("INFO: URI: {0}" -f $URI)
        try{
            $pagedresponse = (Invoke-RestMethod -Headers $headers -Method $method -Uri $uri -ContentType 'application/json' -UseBasicParsing).result
        }catch{
            Log ("ERROR: Service Now request failed")
            Log ("ERROR: StatusCode: {0}" -f $_.Exception.Response.StatusCode.value__)
            Log ("ERROR: StatusDescription: {0}" -f $_.Exception.Response.StatusDescription)
            Log ("ERROR: Message: {0}" -f $_.Exception.Message)
            break;
        }
        $response += $pagedresponse
        $count = $pagedresponse.count
        $offset = $offset + $limit
        Log ("INFO: Read: {0} rows from: {1}" -f $response.Count, $TableName)
    }

    if ($response.Count -gt 0)
    {
        $dtResults = New-Object System.Data.DataTable
        $sqlcmd.CommandText = "SELECT * FROM SN_$TableName WHERE 1=0"
        $dtResults.Load($sqlcmd.ExecuteReader())

        $ScriptBlock=$null

        $InsertStatementLine1 = "INSERT INTO SN_$TableName ("
        $InsertStatementLine2 = "VALUES ("

        foreach($object_properties in $($response[0] | Get-Member | Where-Object{$_.MemberType -eq "NoteProperty"}))
        {
                if ($dtResults.Columns.Contains($object_properties.Name))
                {
                    $InsertStatementLine1 += '"' + $object_properties.Name + '",'
                    $InsertStatementLine2 += '@' + $object_properties.Name + ','
                    # Access the name of the property
                    $ScriptBlock += 'if ($entry.' + $object_properties.Name + '.Value) { [void]$sqlcmd.Parameters.AddWithValue("@' + $object_properties.Name + '", $entry.' + $object_properties.Name + '.Value) }else{ [void]$sqlcmd.Parameters.AddWithValue("@' + $object_properties.Name + '", $entry.' + $object_properties.Name + ") }`n"
                }else{
                    Log ("WARN: Column not in database table. Table name: {0} Column name: {1}" -f $TableName, $($object_properties.Name))
                }
        }

        $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)

        $sqlcmd.CommandText = $InsertStatementLine1.Substring(0,$InsertStatementLine1.Length-1) + ")`n" + $InsertStatementLine2.Substring(0,$InsertStatementLine2.Length-1) + ")"

        $Counter = 0
        Log ("INFO: Start data insert")
        foreach($entry in $response)
        {
            & $ScriptBlock
            [void]$sqlcmd.ExecuteNonQuery()
            $Counter++
        }

        $con.close()

        Log ("INFO: Copied {1} rows to table SN_{0}" -f $tablename, $Counter)
    }else
    {
        Log ("INFO: No records to insert.")
    }
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

        $ImportId = (Get-DwImportDeviceFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName).id

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
        Write-Progress -Activity Uploading -Status "Writing Device Feed Object $RowCount" -PercentComplete (100 * ($RowCount / $DWDeviceDataTable.Rows.Count))

        $Body = $null
        $Body = $Row | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
        Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $Body | out-null

        $RowCount++
    }

    Return "$RowCount devices added"
}


$DLLPath = "$PSScriptRoot\System.Data.SQLite.dll"
$DBPath = "$PSScriptRoot\DWCSN.db"
$FeedName = "XXXXX"

Get-ServiceNowTableSQLite -tableName 'cmdb_ci_computer' -DLLPath $DLLPath -DBPath $DBPath
#User data isn't utilised in this example but the email from the ownership is availble but commented in the SQL to pull the table.
#Get-ServiceNowTableSQLite -tableName 'sys_user' -DLLPath $DLLPath -DBPath $DBPath
Get-ServiceNowTableSQLite -tableName 'core_company' -DLLPath $DLLPath -DBPath $DBPath
Get-ServiceNowTableSQLite -tableName 'cmdb_model' -DLLPath $DLLPath -DBPath $DBPath
#Location and department data is not utilised in this example but can be joined if the data is scraped.
#Get-ServiceNowTableSQLite -tableName 'cmn_department' -DLLPath $DLLPath -DBPath $DBPath
#Get-ServiceNowTableSQLite -tableName 'cmn_location' -DLLPath $DLLPath -DBPath $DBPath


Add-Type -Path $DLLPath

$con = New-Object -TypeName System.Data.SQLite.SQLiteConnection
$con.ConnectionString = "Data Source=$DBPath"

$sqlcmd = $con.CreateCommand()
$sqlcmd.CommandText = (Get-Content ".\ServiceNow SQLite Devices.sql")
$dtDWDeviceData = New-Object System.Data.DataTable
$dtDWDeviceData.Load($sqlcmd.ExecuteReader())

$dtDWServerDetails = New-Object System.Data.DataTable
$sqlcmd.CommandText = "SELECT * FROM APICredentials WHERE FriendlyName = 'Dashworks'"
$dtDWServerDetails.Load($sqlcmd.ExecuteReader())

Invoke-DwImportDeviceFeedDataTable -Instance $($dtDWServerDetails[0].Server) -DWDeviceDataTable $dtDWDeviceData -APIKey $($dtDWServerDetails[0].Password) -FeedName $FeedName

