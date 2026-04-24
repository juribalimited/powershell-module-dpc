function Convert-EntraIdUsersToJuribaDPC {
<#
.SYNOPSIS
Converts Entra ID user data into a Juriba DPC-compatible DataTable.

.DESCRIPTION
Transforms Entra ID user records into a System.Data.DataTable formatted
according to Juriba Dynamic Property Container (DPC) requirements.

The function accepts Entra ID user data represented as DataRow objects,
extracts fixed identity attributes, and dynamically discovers additional
scalar properties that can be safely promoted into Juriba DPC columns.
Complex objects, arrays, and non-scalar values are excluded by design.

An optional IncludeProperties parameter allows selective inclusion of
dynamic properties using wildcard patterns.

.INPUTS
System.Data.DataRow[]

.PARAMETER Rows
An array of System.Data.DataRow objects representing Entra ID user data.
These rows are typically obtained from a prior Graph extraction step
(e.g. Get-EntraIdUser). The input rows must include, at minimum, the
following columns/properties:
id, mailNickname, displayName, securityIdentifier, surname, givenName,
mail, userPrincipalName.

.PARAMETER IncludeProperties
An optional list of property names or wildcard patterns used to control
which dynamically discovered scalar properties are included in the Juriba
DPC output.

Only dynamic scalar properties are filtered; fixed identity columns are
always included. Wildcard matching uses '*' (case-insensitive).

If not specified, all eligible scalar properties are included.

.OUTPUTS
System.Data.DataTable

Returns a Juriba DPC-compatible DataTable containing Entra ID user records
with a fixed identity schema and dynamically generated property columns.

.EXAMPLE
$users = Get-EntraIdUser -AccessToken $AccessToken
$dt = Convert-EntraIdUsersToJuribaDPC -Rows $users.Rows

Retrieves Entra ID users and converts them into a Juriba DPC DataTable
including all eligible scalar properties.

.EXAMPLE
$users = Get-EntraIdUser -AccessToken $AccessToken
$dt = Convert-EntraIdUsersToJuribaDPC `
    -Rows $users.Rows `
    -IncludeProperties "onPremises*", "department", "jobTitle"

Converts Entra ID users into a Juriba DPC DataTable including only selected
dynamic properties.

.NOTES
- Designed for Juriba Dynamic Property Container (DPC) ingestion
- Excludes arrays and complex objects by design
- Fixed identity column mapping:
  - uniqueIdentifier   <- id
  - username           <- mailNickname
  - displayName        <- displayName
  - objectSid          <- securityIdentifier
  - surname            <- surname
  - givenName          <- givenName
  - emailAddress       <- mail
  - userPrincipalName  <- userPrincipalName
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
                "uniqueIdentifier","username","displayName","objectSid",
                "disabled","surname","givenName","emailAddress","userPrincipalName"
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
        username = [string]
        displayName = [string]
        objectSid = [string]
        disabled = [bool]
        surname = [string]
        givenName = [string]
        emailAddress = [string]
        userPrincipalName = [string]
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
        $newRowValues[$index++] = $row.mailNickname
        $newRowValues[$index++] = $row.displayName
        $newRowValues[$index++] = $row.securityIdentifier
        $newRowValues[$index++] = if (-not [bool]::Parse($row.accountEnabled)) { 1 } else { 0 }
        $newRowValues[$index++] = $row.surname
        $newRowValues[$index++] = $row.givenName
        $newRowValues[$index++] = $row.mail
        $newRowValues[$index++] = $row.userPrincipalName

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