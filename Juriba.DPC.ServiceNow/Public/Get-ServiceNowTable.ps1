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
            Write-Debug ("ERROR: StatusCode: {0}" -f $_.Exception.Response.StatusCode.value__)
            Write-Debug ("ERROR: StatusDescription: {0}" -f $_.Exception.Response.StatusDescription)
            Write-Debug ("ERROR: Message: {0}" -f $_.Exception.Message)
            break;
        }
        $response += $pagedresponse
        $count = $pagedresponse.count
        $offset = $offset + $limit
        Write-Debug ("INFO: Read: {0} rows from: {1}" -f $response.Count, $TableName)
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