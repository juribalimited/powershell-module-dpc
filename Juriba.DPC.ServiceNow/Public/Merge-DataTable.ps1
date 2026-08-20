function Merge-DataTable {
    <#
    .Synopsis
    Adds columns from a second data table to the first where rows match on the join keys.

    .Description
    Takes two System.Data.DataTable objects, joins them on the given key columns and copies the requested
    columns from the secondary table onto matching rows of a copy of the primary table. Rows without a
    match keep the added columns empty.

    .Parameter primaryTable
    [System.Data.DataTable] The table to copy and enrich.

    .Parameter secondaryTable
    [System.Data.DataTable] The table supplying the additional column values.

    .Parameter LeftjoinKeyProperty
    The column name in the primary table used as the join key.

    .Parameter rightjoinkeyproperty
    The column name in the secondary table used as the join key.

    .Parameter AddColumns
    Hashtable mapping secondary table column names (keys) to the column names to populate on the primary
    table (values).

    .Outputs
    Output type [System.Data.DataTable]
    A copy of the primary table with the additional columns populated where the join matched.

    .Example
    # Add user_name from sys_user to cmdb_ci_computer rows.
    $dtMerged = Merge-DataTable -primaryTable $dtComputers -secondaryTable $dtSysUser -LeftjoinKeyProperty "assigned_to_link" -rightjoinkeyproperty "sys_id" -AddColumns @{"user_name"="user_name"}
    #>
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

    Write-Debug ("INFO: Starting merge between data tables.")
    $secondaryTable | Out-Null #Added to get past the analyzer. The table is only used in the dynamic scripting.
    $dtMerge = $primaryTable.Copy()
    $ScriptBlock=$null
    $LeftJoinField= '$Row.''' + $LeftjoinKeyProperty + ''''
    # Escape embedded single quotes in the join value, otherwise DataTable.Select throws on values like O'Brien.
    $ScriptBlock = '$leftJoinValue = ([string](' + $LeftJoinField + ')).Replace("''","''''")' + "`n"
    $ScriptBlock += '$joinRow = $secondaryTable.select("['+ $rightjoinkeyproperty + ']=''$leftJoinValue''")' + "`n"
    $AddedColumnList = ''
    Foreach ($AddColumn in $AddColumns.GetEnumerator()) {
        if (!$dtMerge.Columns.Contains($AddColumn.Value))
        {
            $dtMerge.Columns.Add($AddColumn.Value) | Out-Null
        }
        $ScriptBlock += 'if ($joinRow.length -gt 0) {$Row.''' + $($AddColumn.Value) + ''' = $joinRow.''' + $($AddColumn.Name) + "'}`n"
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
        . $ScriptBlock
    }

    Write-Debug ("INFO: Finished merge between data tables. $AddedColumnList added to primary table.")
    return @(,($dtMerge))
}
