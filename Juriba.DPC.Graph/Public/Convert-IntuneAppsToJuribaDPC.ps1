
function Convert-IntuneAppsToJuribaDPC {
<#
.SYNOPSIS
Converts Intune application data into a Juriba DPC-compatible DataTable.

.DESCRIPTION
Transforms Intune managed application records into a System.Data.DataTable
formatted for Juriba Dynamic Property Container (DPC) ingestion.

The function accepts Intune app data as System.Data.DataRow objects (typically
originating from a Microsoft Graph extraction such as /deviceAppManagement/mobileApps),
maps a fixed set of identity fields into standard Juriba columns, and dynamically
discovers additional scalar properties that can be safely promoted to DPC columns.

Arrays and complex/nested objects are excluded by design to ensure the output
is compatible with tabular import processes.

An optional IncludeProperties parameter allows selective inclusion of dynamic
properties using wildcard patterns.

.PARAMETER Rows
An array of System.Data.DataRow objects representing Intune application data.
Rows should contain common Intune application properties such as:
id, publisher, displayName, productVersion, createdDateTime (depending on source).

.PARAMETER IncludeProperties
Optional list of property names or wildcard patterns that control which
dynamically discovered scalar properties are included in the output.

If not specified, all eligible scalar properties are included.

.OUTPUTS
System.Data.DataTable

Returns a Juriba DPC-compatible DataTable where each row represents an Intune
managed application. The output contains a fixed schema plus optional dynamic
scalar property columns.

.EXAMPLE
$dt = Convert-IntuneAppsToJuribaDPC -Rows $appRows

Converts Intune application rows into a Juriba DPC DataTable including all
eligible scalar properties.

.EXAMPLE
$dt = Convert-IntuneAppsToJuribaDPC `
    -Rows $appRows `
    -IncludeProperties "is*", "owner*", "description", "install*"

Converts Intune application rows into a Juriba DPC DataTable including only
selected dynamic properties based on wildcard patterns.

.NOTES
- Designed for Juriba Dynamic Property Container (DPC) ingestion
- Fixed output columns are populated as follows:
  - uniqueIdentifier <- id
  - manufacturer     <- publisher
  - name             <- displayName
  - version          <- productVersion
  - createdDate      <- createdDateTime
- Arrays and complex objects are excluded by design
- Output DataTable is written as a single object (no enumeration)
#>
    [CmdletBinding()]
    [OutputType([System.Data.DataTable])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Data.DataRow[]]$Rows,
        [string[]]$IncludeProperties # Accepts wildcards
    )

    #-------------------------------------------
    # 1. Detect all scalar property names
    #-------------------------------------------
    $scalarProperties = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($row in $Rows) {
        foreach ($col in $row.Table.Columns.ColumnName) {

            # Skip identity fields promoted to top level
            if ($col -in @(
                "uniqueIdentifier","manufacturer","name","version","createdDate"
            )) { continue }

            $value = $row.$col

            # Skip nulls
            if ($null -eq $value) { continue }

            # Skip arrays
            if ($value -is [array]) { continue }

            # Skip complex/nested objects
            if ($value -isnot [ValueType] -and $value -isnot [string]) { continue }

            # Add property
            $scalarProperties.Add($col) | Out-Null
        }
    }

    #-------------------------------------------
    # 2. Apply IncludeProperties filtering
    #-------------------------------------------

    if ($IncludeProperties) {
        # Convert wildcards to regex for performance
        $patterns = $IncludeProperties | ForEach-Object {
            ('^{0}$' -f ([regex]::Escape($_) -replace '\\\*', '.*'))
        }

        $scalarProperties = $scalarProperties |
            Where-Object {
                $name = $_
                foreach ($pattern in $patterns) {
                    if ($name -match $pattern) { return $true }
                }
                return $false
            }
    }

    #-------------------------------------------
    # 3. Build DataTable with dynamic columns
    #-------------------------------------------

    $dt = New-Object System.Data.DataTable

    # Fixed schema
    $fixedColumns = [ordered]@{
        uniqueIdentifier = [string]
        manufacturer = [string]
        name = [string]
        version = [string]
        createdDate = [datetime]
    }

    foreach ($name in $fixedColumns.Keys) {
        [void]$dt.Columns.Add($name, $fixedColumns[$name])
    }

    # Dynamic scalar property columns
    foreach ($p in $scalarProperties) {
        [void]$dt.Columns.Add($p, [string])
    }

    #-------------------------------------------
    # 4. Populate DataTable rows
    #-------------------------------------------

    foreach ($row in $Rows) {

        $newRowValues = New-Object object[] $dt.Columns.Count
        $index = 0

        # Fixed fields
        $newRowValues[$index++] = $row.id
        $newRowValues[$index++] = $row.publisher
        $newRowValues[$index++] = $row.displayName
        $newRowValues[$index++] = $row.productVersion
        $newRowValues[$index++] = $row.createdDateTime

        # Dynamic fields
        foreach ($p in $scalarProperties) {
            $value = $row.$p

            if ($value -is [array]) { $value = $null }
            elseif ($value -isnot [ValueType] -and $value -isnot [string]) { $value = $null }

            $newRowValues[$index++] = $value
        }

        [void]$dt.Rows.Add($newRowValues)
    }

    #-------------------------------------------
    # 5. Return DataTable without enumeration
    #-------------------------------------------

    $PSCmdlet.WriteObject($dt, $false)
}