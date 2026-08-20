function Convert-JuribaDeptFromServiceNowSys_User {
    <#
    .Synopsis
    Returns a datatable in the Juriba DPC department import format from ServiceNow sys_user data.

    .Description
    Takes in a datatable of ServiceNow sys_user records returned from Get-ServiceNowTable and builds the
    department hierarchy (companies as top level, departments as their children) required by the Juriba DPC
    department import API, including the list of user reference paths attached to each department.

    .Parameter UserDataTable
    [System.Data.DataTable] object returned from the Get-ServiceNowTable function for the sys_user table.
    Must include the company, company_link, department, department_link and user_name columns.

    .Parameter UserFeedId
    The id of the Juriba DPC user import feed used to build the user reference paths. Defaults to 1.

    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema used by the Juriba DPC department import API populated from the ServiceNow sys_user data.

    .Example
    # Convert the data for use with the Juriba DPC department import API.
    $dtDepartments = Convert-JuribaDeptFromServiceNowSys_User -UserDataTable $dtSysUser -UserFeedId 2
    #>
    [Alias("Convert-DwAPIDeptFromServiceNowSys_User")]
    [OutputType([System.Data.DataTable])]
    Param(
        [Parameter(Mandatory=$True)]
        [System.Data.DataTable] $UserDataTable,
        [Parameter(Mandatory=$false)]
        [string] $UserFeedId = 1
    )

    Write-Debug ("INFO: Starting conversion for sys_user to the Juriba DPC department import format.")

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

    Write-Debug ("INFO: Finished conversion for sys_user to the Juriba DPC department import format.")
    Return ,$dataTable
}
