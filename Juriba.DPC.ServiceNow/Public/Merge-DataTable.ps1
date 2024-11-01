function Merge-DataTable {
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
    
    Write-Debug ("INFO: Starting merge between data tables.")
    $secondaryTable | Out-Null #Added to get past the analyzer. The table is only used in the dynamic scripting.
    $dtMerge = $primaryTable.Copy()
    $ScriptBlock=$null
    $LeftJoinField= '$Row.''' + $LeftjoinKeyProperty + ''''
    $ScriptBlock = '$joinRow = $secondaryTable.select("['+ $rightjoinkeyproperty + ']=''$(' + $LeftJoinField + ')''")' + "`n"
    $AddedColumnList = ''
    Foreach ($AddColumn in $AddColumns.GetEnumerator()) {
        if (!$dtMerge.Columns.Contains($AddColumn.Value))
        {
            $dtMerge.Columns.Add($AddColumn.Value) | Out-Null
        }
        $ScriptBlock += '$Row.''' + $($AddColumn.Value) + ''' = $joinRow.''' + $($AddColumn.Name) + "'`n"
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

    Write-Debug ("INFO: Finished merge between data tables. $AddedColumnList added to primary table.")
    return @(,($dtMerge)) 
}