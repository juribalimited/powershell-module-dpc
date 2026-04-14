function Convert-EntraIdGroupsToJuribaDPC {
<#
.SYNOPSIS
Converts Entra ID group data into a DPC-compatible DataTable.

.DESCRIPTION
Transforms Entra ID group records into a System.Data.DataTable formatted for
DPC-compatible ingestion.

The function accepts Entra ID group data represented as System.Data.DataRow objects
(typically sourced from a Microsoft Graph extraction such as /groups), maps a fixed
set of identity fields into standard columns, and dynamically discovers additional
scalar properties that can be safely promoted into DPC-compatible columns.

Complex objects, arrays, and non-scalar values are excluded by design to ensure the
output remains tabular and import-friendly.

An optional IncludeProperties parameter allows selective inclusion of dynamically
discovered scalar properties using wildcard patterns.

.INPUTS
System.Data.DataRow[]

.PARAMETER Rows
An array of System.Data.DataRow objects representing Entra ID group data.

These rows are typically obtained from a prior Graph extraction step (e.g. Get-EntraIdGroup)
and should include, at minimum, the columns/properties referenced by the fixed mapping:
id, displayName, securityEnabled, description.

.PARAMETER IncludeProperties
Optional list of property names or wildcard patterns controlling which dynamically
discovered scalar properties are included as additional DPC-compatible columns.

Only dynamically discovered scalar properties are filtered; fixed identity columns
are always included. Wildcard matching uses '*' (case-insensitive).

If not specified, all eligible scalar properties are included.

.OUTPUTS
System.Data.DataTable

Returns a DPC-compatible DataTable where each row represents an Entra ID group.
The output contains a fixed schema plus optional dynamic scalar property columns.

.EXAMPLE
$groups = Get-EntraIdGroup -AccessToken $AccessToken
$dt = Convert-EntraIdGroupsToJuribaDPC -Rows $groups.Rows

Retrieves Entra ID groups and converts them into a DPC-compatible DataTable
including all eligible scalar properties.

.EXAMPLE
$groups = Get-EntraIdGroup -AccessToken $AccessToken
$dt = Convert-EntraIdGroupsToJuribaDPC `
    -Rows $groups.Rows `
    -IncludeProperties "onPremises*", "mailEnabled", "visibility"

Converts Entra ID groups into a DPC-compatible DataTable including only selected
dynamic properties based on wildcard patterns.

.NOTES
- Designed for DPC-compatible ingestion
- Excludes arrays and complex objects by design
- Fixed column mapping:
  - uniqueIdentifier <- id
  - name            <- displayName
  - type            <- derived from securityEnabled (as implemented)
  - description     <- description
- The 'type' mapping in this function is implemented as:
  - securityEnabled == "True"  -> "-2147483646"
  - otherwise                  -> "2"
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
                "uniqueIdentifier","name","type","description"
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
        name = [string]
        "type" = [string]
        description = [string]
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
        $newRowValues[$index++] = $row.displayName
        $newRowValues[$index++] = if ($row.securityEnabled -eq "True") {
            "-2147483646"
        } else {
            "2"
        }
        $newRowValues[$index++] = $row.description

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