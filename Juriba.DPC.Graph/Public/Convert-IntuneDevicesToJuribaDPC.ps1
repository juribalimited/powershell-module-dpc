function Convert-IntuneDevicesToJuribaDPC {
<#
.SYNOPSIS
Converts Intune device data into a Juriba DPC-compatible DataTable.

.DESCRIPTION
Transforms Intune managed device records into a System.Data.DataTable formatted
according to Juriba Dynamic Property Container (DPC) ingestion requirements.

The function accepts Intune device data represented as System.Data.DataRow objects
(typically sourced from a Microsoft Graph extraction such as
/deviceManagement/managedDevices), maps a fixed set of device identity and
inventory fields into standard DPC columns, and dynamically discovers additional
scalar properties that can be safely promoted into DPC columns.

Complex objects, arrays, and non-scalar values are excluded by design to ensure
tabular compatibility.

An optional IncludeProperties parameter allows selective inclusion of dynamic
properties using wildcard patterns. An optional ImportId may be used to build an
owner reference value when userId is present.

.INPUTS
System.Data.DataRow[]

.PARAMETER Rows
An array of System.Data.DataRow objects representing Intune managed device data.

The input rows are typically obtained from a prior Microsoft Graph extraction and
should include, at minimum, the following columns/properties used by the fixed
mapping:
id, deviceName, operatingSystem, osVersion, manufacturer, model, serialNumber,
physicalMemoryInBytes, ethernetMacAddress, wiFiMacAddress, totalStorageSpaceInBytes,
freeStorageSpaceInBytes, userId.

.PARAMETER IncludeProperties
Optional list of property names or wildcard patterns controlling which dynamically
discovered scalar properties are included as additional DPC columns.

Only dynamically discovered scalar properties are filtered; fixed identity columns
are always included. Wildcard matching uses '*' (case-insensitive).

If not specified, all eligible scalar properties are included.

.PARAMETER ImportId
Optional import identifier used to construct an owner reference when userId is present.

If userId is populated and ImportId is not supplied, the owner reference may be
blank or invalid depending on downstream expectations.

.OUTPUTS
System.Data.DataTable

Returns a Juriba DPC-compatible DataTable where each row represents an Intune
managed device. The output contains a fixed schema plus optional dynamic scalar
property columns.

.EXAMPLE
$devices = Get-IntuneDevice -AccessToken $AccessToken
$dt = Convert-IntuneDevicesToJuribaDPC -Rows $devices.Rows

Retrieves Intune managed devices and converts them into a DPC-compatible DataTable
including all eligible scalar properties.

.EXAMPLE
$devices = Get-IntuneDevice -AccessToken $AccessToken
$dt = Convert-IntuneDevicesToJuribaDPC `
    -Rows $devices.Rows `
    -ImportId $ImportId `
    -IncludeProperties "azureAD*", "complianceState", "managementAgent"

Converts Intune devices into a DPC-compatible DataTable including only selected
dynamic properties, and builds an owner reference when userId exists.

.NOTES
- Designed for Juriba Dynamic Property Container (DPC) ingestion
- Excludes arrays and complex objects by design
- Fixed column mapping:
  - uniqueIdentifier         <- id
  - hostname                 <- deviceName
  - operatingSystemName      <- operatingSystem
  - operatingSystemVersion   <- osVersion
  - computerManufacturer     <- manufacturer
  - computerModel            <- model (truncated to 50 chars)
  - chassisType              <- model (truncated to 50 chars) [as implemented]
  - firstSeenDate            <- null [as implemented]
  - lastSeenDate             <- null [as implemented]
  - serialNumber             <- serialNumber
  - memoryKb                 <- physicalMemoryInBytes / 1024
  - macAddress               <- ethernetMacAddress, else wiFiMacAddress
  - totalHDDSpaceMb          <- totalStorageSpaceInBytes / (1024*1024)
  - targetDriveFreeSpaceMb   <- freeStorageSpaceInBytes / (1024*1024)
  - owner                    <- "/imports/{ImportId}/users/{userId}" when userId exists
- Output DataTable is written as a single object (no enumeration)
#>
    [CmdletBinding()]
    [OutputType([System.Data.DataTable])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Data.DataRow[]]$Rows,
        [string[]]$IncludeProperties, # Accepts wildcards
        [parameter(Mandatory=$False)]
        [string]$ImportId = $null       
    )

    #-------------------------------------------
    # 1. Detect all scalar property names
    #-------------------------------------------
    $scalarProperties = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($row in $Rows) {
        foreach ($col in $row.Table.Columns.ColumnName) {

            # Skip identity fields promoted to top level
            if ($col -in @(
                "uniqueIdentifier","hostname","operatingSystemName","operatingSystemVersion",
                "computerManufacturer","computerModel","chassisType","serialNumber","memoryKb",
                "macAddress","totalHDDSpaceMb","targetDriveFreeSpaceMb","owner"
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
        hostname = [string]
        operatingSystemName = [string]
        operatingSystemVersion = [string]
        computerManufacturer = [string]
        computerModel = [string]
        chassisType = [string]
        serialNumber = [string]
        memoryKb = [string]
        macAddress = [string]
        totalHDDSpaceMb = [string]
        targetDriveFreeSpaceMb = [string]
        owner = [string]
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
        $newRowValues[$index++] = $row.deviceName
        $newRowValues[$index++] = $row.operatingSystem
        $newRowValues[$index++] = $row.osVersion
        $newRowValues[$index++] = $row.manufacturer
        $newRowValues[$index++] = if($row.model){$row.model.subString(0, [System.Math]::Min(50, $row.model.Length))}else {[DBNULL]::value}
        $newRowValues[$index++] = if($row.model){$row.model.subString(0, [System.Math]::Min(50, $row.model.Length))}else {[DBNULL]::value}
        $newRowValues[$index++] = $row.serialNumber
        $newRowValues[$index++] = if($row.physicalMemoryInBytes){($row.physicalMemoryInBytes)/1024}else{[DBNULL]::Value}
        $newRowValues[$index++] = if($row.ethernetMacAddress){$row.ethernetMacAddress}elseif($row.wiFiMacAddress){$row.wiFiMacAddress}else{[DBNULL]::Value}
        $newRowValues[$index++] = if($row.totalStorageSpaceInBytes){$row.totalStorageSpaceInBytes/(1024*1024)}else{[DBNULL]::Value}
        $newRowValues[$index++] = if($row.freeStorageSpaceInBytes){$row.freeStorageSpaceInBytes/(1024*1024)}else{[DBNULL]::Value}
        $newRowValues[$index++] = If($row.userId){"/imports/$ImportId/users/$($Row.userId)"}else{[DBNULL]::Value}

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