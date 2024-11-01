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
    Write-Debug ("INFO: Starting conversion for cmn_department to DWAPI format.")

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

    Write-Debug ("INFO: Finished conversion for cmn_department to DWAPI format.")
    Return ,$dataTable
}