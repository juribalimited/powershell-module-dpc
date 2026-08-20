function Get-ServiceNowTable {
    <#
    .Synopsis
    Reads a ServiceNow table and returns it as a System.Data.DataTable.

    .Description
    Uses the ServiceNow REST table API to read all rows of the named table in pages, expanding reference
    fields into display-value and _link columns, and returns the result as a DataTable for use with the
    Convert-Juriba* functions. Authenticates with the token object returned from Get-ServiceNowToken
    (OAuth or Basic) and refreshes OAuth tokens with Update-ServiceNowToken when they near expiry.

    .Parameter TableName
    The name of the ServiceNow table to read. For example, sys_user or alm_hardware.

    .Parameter NameValuePairs
    Optional. Additional query string parameters appended to the table API request, for example
    sysparm_query filters or a sysparm_fields list. If omitted, all fields of all rows are returned.

    .Parameter ChunkSize
    The number of rows to request per page. Defaults to 1000.

    .Parameter AuthToken
    The token object returned from Get-ServiceNowToken, containing the server URL and authorization header.

    .Outputs
    Output type [System.Data.DataTable]
    A table containing the rows read from the ServiceNow table.

    .Example
    $dtSysUser = Get-ServiceNowTable -TableName sys_user -AuthToken $OAuthToken
    #>
    [OutputType([System.Data.DataTable])]
param (
    [Parameter(Mandatory=$true)][string] $TableName,
    [Parameter(Mandatory=$false)][string] $NameValuePairs,
    [Parameter(Mandatory=$false)][string] $ChunkSize = 1000,
    [Parameter(Mandatory=$true)][PSObject] $AuthToken
    )
    $OAuthToken=$AuthToken.PSObject.Copy()

    Write-Debug ("INFO: Get-ServiceNowTable")
    Write-Debug ("INFO: Table Name: {0}" -f $tablename)
    Write-Debug ("INFO: Chunk Size: {0}" -f $ChunkSize)

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
    $stopwatch =  [system.diagnostics.stopwatch]::StartNew()
    $stopwatch2 =  [system.diagnostics.stopwatch]::StartNew()
    while ($count -eq $limit)
    {
        #Check to see if the OAuth token is still going to be valid for the request. If not, get a new one.
        if ($OAuthToken.expires -lt (Get-date).AddMinutes(10))
        {
            Write-Debug ("INFO: Token Expires at: {0}, current time: {1} - forcing new OAuth token" -f $OAuth.expires, (get-date))
            $OAuthToken = Update-ServiceNowToken -OAuthToken $OAuthToken
            [void]$headers.Remove("Authorization")
            [void]$headers.Add('Authorization',$OAuthToken.AuthHeader)
        }

        # Specify endpoint uri
        $uri="$($OAuthToken.ServerURL)/api/now/table/$TableName"+"?sysparm_limit={1}&sysparm_offset={0}&sysparm_display_value=true" -f $offset, $limit
        if($NameValuePairs){$uri = $uri + '&' + $NameValuePairs}
        Write-Debug ("INFO: URI: {0}" -f $URI)
        try{
            $pagedresponse = (Invoke-RestMethod -Headers $headers -Method $method -Uri $uri -ContentType 'application/json' -UseBasicParsing).result
        }catch{
            Write-Debug ("ERROR: Service Now request failed")
            #Write-Debug ("ERROR: StatusCode: {0}" -f $_.Exception.Response.StatusCode.value__)
            #Write-Debug ("ERROR: StatusDescription: {0}" -f $_.Exception.Response.StatusDescription)
            Write-Debug ("ERROR: Message: {0}" -f $_.Exception.Message)
            break;
        }
        $response += $pagedresponse
        $count = $pagedresponse.count
        $offset = $offset + $limit
        Write-Debug ("INFO: Read: {0} rows from: {1}. This batch took {2}ms" -f $response.Count, $TableName, $stopwatch2.ElapsedMilliseconds)
        $stopwatch2.Restart()
    }
    Write-Debug ("INFO: Time to Pull from ServiceNow: {0}ms" -f $stopwatch.ElapsedMilliseconds)
    $stopwatch.Restart()
    $dtResults = New-Object System.Data.DataTable
    $ScriptBlock=$null
    $ScriptBlock += '$entryColumnList = ($entry | Get-Member -MemberType NoteProperty).Name'+"`n"
    if ($response.count -gt 0)
    {
        $DataColumnList = @{}
        $response | foreach-Object {$_ | get-member -MemberType NoteProperty} | Where-Object {$null -eq $DataColumnList[$($_.Name)]} | foreach-Object {$DataColumnList.Add($_.Name,$_.Name) | Out-Null}
        foreach($DataColumnName in ($DataColumnList.GetEnumerator()).Name)
        {
            if (!$dtResults.Columns.Contains($DataColumnName))
            {
                $stopwatch2.Restart()
                $GetPopulatedEntryBlock='if($response | where-object{$_.' + $DataColumnName + ' -ne [DBNULL]::Value} | select-object -First 1) {$response | where-object{$_.' + $DataColumnName + ' -ne [DBNULL]::Value} | select-object -First 1 | Get-Member | where-object{$_.MemberType -eq "NoteProperty"} | where-object{$_.Name -eq ''' + $DataColumnName + '''}}'
                $GetPopulatedEntryBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($GetPopulatedEntryBlock)
                $PopulatedOutput = & $GetPopulatedEntryBlock
                if ($PopulatedOutput){
                    $DataColumn = $PopulatedOutput
                }
                else{
                    $DataColumn = $response | select-object -First 1 | Get-Member | where-object{$_.MemberType -eq "NoteProperty"} | where-object{$_.Name -eq $DataColumnName}
                }

                if ($DataColumn.Definition.substring(0,$DataColumn.Definition.IndexOf(' ')) -eq 'System.Management.Automation.PSCustomObject')
                {
                    $datatype = 'string'

                    $dtResults.Columns.Add($DataColumn.Name,$datatype) | Out-Null
                    $dtResults.Columns.Add($DataColumn.Name + "_link",$datatype) | Out-Null
                    $ScriptBlock += 'if ($entryColumnList.Contains(''' + $DataColumn.Name + ''') -and $entry.' + $DataColumn.Name + '.getType().Name -eq "PSCustomObject") {$DataRow.' + $DataColumn.Name + ' = $entry.' + $DataColumn.Name + '.display_value} else {$DataRow.' + $DataColumn.Name + " = [DBNULL]::Value};`n"
                    $ScriptBlock += 'if ($entryColumnList.Contains(''' + $DataColumn.Name + ''') -and $entry.' + $DataColumn.Name + '.getType().Name -eq "PSCustomObject") {$DataRow.' + $DataColumn.Name + '_link = $entry.' + $DataColumn.Name + '.link.substring($entry.' + $DataColumn.Name + '.link.LastIndexOf(''/'')+1) } else {$DataRow.' + $DataColumn.Name + " = [DBNULL]::Value};`n"
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
                    $ScriptBlock += 'if ($entryColumnList.Contains(''' + $DataColumn.Name + ''')) {$DataRow.' + $DataColumn.Name + ' = $entry.' + $DataColumn.Name + ' } else {$DataRow.' + $DataColumn.Name + " = [DBNULL]::Value};`n"
                }
            }
        }
        Write-Debug ("INFO: Time to Process Columns: {0}ms" -f $stopwatch.ElapsedMilliseconds)

        $ScriptBlockToRun = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptBlock)
        $stopwatch.Restart()
        foreach($entry in $response)
        {
            $DataRow = $dtResults.NewRow()

            . $ScriptBlockToRun

            $dtResults.Rows.Add($DataRow)
        }
        Write-Debug ("INFO: Time to Process Rows: {0}ms" -f $stopwatch.ElapsedMilliseconds)
        $stopwatch = $null
    }
    return @(,($dtResults))
}
