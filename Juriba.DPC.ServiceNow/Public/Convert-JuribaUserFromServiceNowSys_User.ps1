function Convert-JuribaUserFromServiceNowSys_User {
    <#
    .Synopsis
    Returns a datatable in the Juriba DPC user import format from ServiceNow sys_user data.

    .Description
    Takes in a datatable of ServiceNow sys_user records returned from Get-ServiceNowTable and strips the
    fields required for insertion into the Juriba DPC user import API. Rows without a user_name are skipped
    and a placeholder email address is substituted where the source email is not valid.

    .Parameter ServiceNowDataTable
    [System.Data.DataTable] object returned from the Get-ServiceNowTable function for the sys_user table.

    .Parameter CustomFields
    Optional hashtable mapping Juriba DPC custom field names (keys) to sys_user column names (values) to be
    added to the output table.

    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema used by the Juriba DPC user import API populated from the ServiceNow sys_user data.

    .Example
    # Convert the data for use with the Juriba DPC user import API.
    $dtUsers = Convert-JuribaUserFromServiceNowSys_User -ServiceNowDataTable $dtSysUser
    #>
    [Alias("Convert-DwAPIUserFromServiceNowSys_User")]
    [OutputType([System.Data.DataTable])]
    Param(
        [Parameter(Mandatory=$True)][System.Data.DataTable] $ServiceNowDataTable,
        [parameter(Mandatory=$False)][hashtable]$CustomFields = @{}
    )

    Write-Debug ("INFO: Starting conversion for sys_user to the Juriba DPC user import format.")

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

    Write-Debug ("INFO: Finished conversion for sys_user to the Juriba DPC user import format.")
    Return ,$dataTable
}
