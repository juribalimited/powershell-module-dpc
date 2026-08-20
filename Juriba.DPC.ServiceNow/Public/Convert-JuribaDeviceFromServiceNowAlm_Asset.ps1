function Convert-JuribaDeviceFromServiceNowAlm_Asset {
    <#
    .Synopsis
    Returns a datatable in the Juriba DPC device import format from ServiceNow alm_asset data.

    .Description
    Takes in a datatable of ServiceNow alm_hardware/alm_asset records returned from Get-ServiceNowTable and
    strips the fields required for insertion into the Juriba DPC device import API, including the owner
    reference path when a user_name column is present.

    .Parameter ServiceNowDataTable
    [System.Data.DataTable] object returned from the Get-ServiceNowTable function for the alm_asset table.

    .Parameter UserFeedId
    The id of the Juriba DPC user import feed used to build the owner reference paths. Defaults to 1.

    .Parameter CustomFields
    Optional hashtable mapping Juriba DPC custom field names (keys) to alm_asset column names (values) to be
    added to the output table. Keys ending in _static are written with their value as a literal instead.

    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema used by the Juriba DPC device import API populated from the ServiceNow alm_asset data.

    .Example
    # Convert the data for use with the Juriba DPC device import API.
    $dtDevices = Convert-JuribaDeviceFromServiceNowAlm_Asset -ServiceNowDataTable $dtAlmAsset -UserFeedId 3
    #>
    [Alias("Convert-DwAPIDeviceFromServiceNowAlm_Asset")]
    [OutputType([System.Data.DataTable])]
    Param(
        [Parameter(Mandatory=$True)][System.Data.DataTable] $ServiceNowDataTable,
        [Parameter(Mandatory=$false)][string] $UserFeedId = "1",
        [parameter(Mandatory=$False)][hashtable]$CustomFields = @{}
    )

    Write-Debug ("INFO: Starting conversion for alm_asset to the Juriba DPC device import format.")

    $dataTable = New-Object System.Data.DataTable
    $dataTable.Columns.Add("uniqueIdentifier", [string]) | Out-Null
    $dataTable.Columns.Add("hostname", [string]) | Out-Null
    $dataTable.Columns.Add("operatingSystemName", [string]) | Out-Null
    $dataTable.Columns.Add("operatingSystemVersion", [string]) | Out-Null
    $dataTable.Columns.Add("operatingSystemServicePack", [string]) | Out-Null
    $dataTable.Columns.Add("computerManufacturer", [string]) | Out-Null
    $dataTable.Columns.Add("computerModel", [string]) | Out-Null
    $dataTable.Columns.Add("chassisType", [string]) | Out-Null
    $dataTable.Columns.Add("virtualMachine", [string]) | Out-Null
    $dataTable.Columns.Add("purchaseDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("buildDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("serialNumber", [string]) | Out-Null
    $dataTable.Columns.Add("processorCount", [string]) | Out-Null
    $dataTable.Columns.Add("processorSpeed", [string]) | Out-Null
    $dataTable.Columns.Add("processorManufacturer", [string]) | Out-Null
    $dataTable.Columns.Add("totalHDDSpaceMb", [string]) | Out-Null
    $dataTable.Columns.Add("memoryMB", [string]) | Out-Null
    $dataTable.Columns.Add("assetTag", [string]) | Out-Null
    $dataTable.Columns.Add("warrantyDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("owner", [string]) | Out-Null
    ##Custom Fields
    if ($CustomFields.count -gt 0)
    {
        foreach($CustomFieldName in $CustomFields.GetEnumerator())
        {
            $dataTable.Columns.Add($CustomFieldName.name, [string]) | Out-Null
        }
    }

    foreach ($Row in $ServiceNowDataTable) {

        $NewRow = $null
        $NewRow = $dataTable.NewRow()
        $NewRow.uniqueIdentifier = $Row.sys_id
        $NewRow.hostname = $Row.asset_tag
        if ($Row.os -ne [DBNULL]::Value) {$NewRow.operatingSystemName = $Row.os}
        if ($Row.os_version -ne [DBNULL]::Value) {$NewRow.operatingSystemVersion = $Row.os_version}
        if ($Row.os_service_pack -ne [DBNULL]::Value) {$NewRow.operatingSystemServicePack = $Row.os_service_pack}
        $NewRow.computerManufacturer = $Row.manufacturer
        if ($Row.model.Length -gt 50) {$NewRow.computerModel = $Row.model.substring(0,50)} else {$NewRow.computerModel = $Row.model}
        $NewRow.chassisType = $Row.form_factor
        if ($Row.virtual -ne [DBNULL]::Value) {$NewRow.virtualMachine = $Row.virtual}
        if ($Row.purchase_date -ne [DBNULL]::Value -and $Row.purchase_date -gt '1900-01-01') {$NewRow.purchaseDate = $Row.purchase_date}
        if ($Row.install_date -ne [DBNULL]::Value) {$NewRow.buildDate = $Row.install_date}
        if ($Row.serial_number -ne [DBNULL]::Value) {$NewRow.serialNumber = $Row.serial_number}
        if ($Row.cpu_count -ne [DBNULL]::Value) {$NewRow.processorCount = $Row.cpu_count}
        if ($Row.cpu_speed -ne [DBNULL]::Value) {$NewRow.processorSpeed = ([int]$Row.cpu_speed)}
        if ($Row.cpu_type -ne [DBNULL]::Value) {$NewRow.processorManufacturer = $Row.cpu_type}
        if ($Row.disk_space -ne [DBNULL]::Value) {$NewRow.totalHDDSpaceMb = ([int]$Row.disk_space)*1024}
        if ($Row.ram -ne [DBNULL]::Value) {$NewRow.memoryMB = ([int]$Row.ram)*1024}
        $NewRow.assetTag = $Row.asset_tag
        if ($Row.warranty_expiration -ne [DBNULL]::Value -and $Row.warranty_expiration -gt '1900-01-01') {$NewRow.warrantyDate = $Row.warranty_expiration}
        if ($Row.user_name -ne [DBNULL]::Value) {$NewRow.owner = ("/imports/users/{0}/items/{1}" -f $UserFeedId, $Row.user_name)} else {$NewRow.owner = [DBNULL]::Value}
        if ($CustomFields.count -gt 0)
        {
            foreach($CustomFieldName in $CustomFields.GetEnumerator())
            {
                if ($CustomFieldName.name -like '*_static')
                {
                    $NewRow.$($CustomFieldName.name) = $CustomFieldName.value
                }
                elseif ($Row.$($CustomFieldName.value) -ne [DBNULL]::Value) {$NewRow.$($CustomFieldName.name) = $Row.$($CustomFieldName.value)}
            }
        }
        $dataTable.Rows.Add($NewRow)
    }

    Write-Debug ("INFO: Finished conversion for alm_asset to the Juriba DPC device import format.")
    Return @(,($dataTable))
}
