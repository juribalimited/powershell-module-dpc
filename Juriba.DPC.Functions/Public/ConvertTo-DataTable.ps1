function ConvertTo-DataTable {
<#
.SYNOPSIS
Takes an array and converts it to a datatable, useful for sql or bulk transactions. All objects must be the same (or at least share properties with the first object)
.EXAMPLE
convertto-datatable @(
    [PSCustomObject]@{Name = 'Test'; Food = 'Burgers' },
    [PSCustomObject]@{Name = 'Test2'; Food = 'Fries' },
    [PSCustomObject]@{Name = 'Test3'; Food = 'Coke' },
    [PSCustomObject]@{Name = 'Test4'; Food = 'Sandwich' }
)
#>
    [OutputType([System.Data.DataTable])]
    [CmdletBinding()]
    param([Object[]]$array)

    #Makes a new table
    $dataTable = New-Object System.Data.DataTable

    #We are assuming all items are the same.
    foreach ($column in $array[0].psobject.properties.name) {
        [void]$dataTable.Columns.Add($column)
    }

    [string[]]$columns = $dataTable.columns.columnName

    $i = 1
    $total = $array.count
    Write-Debug "Adding $total rows to datatable"
    $StopWatch = new-object system.diagnostics.stopwatch
    $StopWatch.Start()
    foreach ($item in $array) {
        
        $row = $dataTable.NewRow()
        foreach ($property in $columns) {
            $row.$property = $item.$property
        }
        [void]$dataTable.Rows.Add($row)
        $i++
    }
    $StopWatch.Stop()
    write-debug "Add to table completed in $($StopWatch.Elapsed.TotalMilliseconds)ms"
    $StopWatch = $null

    return ,$dataTable
}