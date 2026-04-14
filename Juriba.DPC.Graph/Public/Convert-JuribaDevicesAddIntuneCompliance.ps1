function Convert-JuribaDevicesAddIntuneCompliance {
    [CmdletBinding()]
    [OutputType([System.Data.DataTable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.DataTable] $JuribaDevices,

        [Parameter(Mandatory = $true)]
        [Array] $Summary
    )

    # Create a new untyped DataTable
    $newTable = New-Object System.Data.DataTable "JuribaDevicesExtended"

    # Copy the original schema (column names + data types)
    foreach ($col in $JuribaDevices.Columns) {
        $newCol = New-Object System.Data.DataColumn $col.ColumnName, $col.DataType
        $null = $newTable.Columns.Add($newCol)  # suppress output
    }

    # Add new dynamic columns
    $null = $newTable.Columns.Add("nonCompliantPolicies", [string])       # suppress output
    $null = $newTable.Columns.Add("nonCompliantPolicyCount", [string])    # suppress output

    # Copy rows from the original typed table
    foreach ($row in $JuribaDevices.Rows) {
        $newRow = $newTable.NewRow()
        $null = ($newRow.ItemArray = $row.ItemArray)  # suppress hidden emitter
        $null = $newTable.Rows.Add($newRow)           # suppress output
    }

    # Build lookup hashtable from summary
    $summaryLookup = @{}
    foreach ($row in $Summary) {
        if ($null -ne $row.deviceId -and $row.deviceId -ne "") {
            $summaryLookup[$row.deviceId] = $row  # hashtable assignment doesn't emit
        }
    }

    # Populate new columns
    foreach ($row in $newTable.Rows) {

        $deviceId = $row["uniqueIdentifier"]

        # Handle null/empty deviceId safely → write SQL NULLs via DBNull
        if ([string]::IsNullOrWhiteSpace($deviceId)) {
            # $row["nonCompliantPolicies"]    = [DBNull]::Value
            # $row["nonCompliantPolicyCount"] = [DBNull]::Value
            $row["nonCompliantPolicies"]    = ""
            $row["nonCompliantPolicyCount"] = "0"
            continue
        }

        if ($summaryLookup.ContainsKey($deviceId)) {
            $summaryRow = $summaryLookup[$deviceId]
            $row["nonCompliantPolicies"]    = $summaryRow.nonCompliantPolicies
            $row["nonCompliantPolicyCount"] = $summaryRow.nonCompliantPolicyCount
        }
        else {
            # $row["nonCompliantPolicies"]    = [DBNull]::Value
            # $row["nonCompliantPolicyCount"] = [DBNull]::Value
            $row["nonCompliantPolicies"]    = ""
            $row["nonCompliantPolicyCount"] = "0"
        }
    }

    # --- Critical: ensure the function returns ONE DataTable object, not an array ---
    # Option A (works everywhere): unary comma prevents enumeration
    return ,$newTable

    # Option B (PowerShell 5+): uncomment this and remove the 'return' above if preferred
    # Write-Output -NoEnumerate $newTable
}