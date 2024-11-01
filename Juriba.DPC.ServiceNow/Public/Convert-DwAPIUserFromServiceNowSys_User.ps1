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