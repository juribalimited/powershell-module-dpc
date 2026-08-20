function Convert-JuribaLocationFromServiceNowCMN_Location {
    <#
    .Synopsis
    Returns a datatable in the Juriba DPC location import format from ServiceNow cmn_location data.

    .Description
    Takes in a datatable of ServiceNow cmn_location records returned from Get-ServiceNowTable and strips the
    fields required for insertion into the Juriba DPC location import API. When user and/or device tables are
    supplied, the users and devices located at each location are attached as reference paths.

    .Parameter ServiceNowDataTable
    [System.Data.DataTable] object returned from the Get-ServiceNowTable function for the cmn_location table.

    .Parameter UserDataTable
    Optional. [System.Data.DataTable] of sys_user records (with a location_link column) used to attach users
    to each location.

    .Parameter UserFeedId
    The id of the Juriba DPC user import feed used to build the user reference paths. Defaults to 1.

    .Parameter DeviceDataTable
    Optional. [System.Data.DataTable] of device records (with a location_link column) used to attach devices
    to each location.

    .Parameter DeviceFeedId
    The id of the Juriba DPC device import feed used to build the device reference paths. Defaults to 1.

    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema used by the Juriba DPC location import API populated from the ServiceNow cmn_location data.

    .Example
    # Convert the data for use with the Juriba DPC location import API.
    $dtLocations = Convert-JuribaLocationFromServiceNowCMN_Location -ServiceNowDataTable $dtLocation -UserDataTable $dtSysUser -UserFeedId 2
    #>
    [Alias("Convert-DwAPILocationFromServiceNowCMN_Location")]
    [OutputType([System.Data.DataTable])]
    Param(
        [Parameter(Mandatory=$True)]
        [System.Data.DataTable] $ServiceNowDataTable,
        [Parameter(Mandatory=$false)]
        [System.Data.DataTable] $UserDataTable,
        [Parameter(Mandatory=$false)]
        [string] $UserFeedId = 1,
        [Parameter(Mandatory=$false)]
        [System.Data.DataTable] $DeviceDataTable,
        [Parameter(Mandatory=$false)]
        [string] $DeviceFeedId = 1
    )

    Write-Debug ("INFO: Starting conversion for cmn_location to the Juriba DPC location import format.")

    $dataTable = New-Object System.Data.DataTable
    $dataTable.Columns.Add("uniqueIdentifier", [string]) | Out-Null
    $dataTable.Columns.Add("name", [string]) | Out-Null
    $dataTable.Columns.Add("region", [string]) | Out-Null
    $dataTable.Columns.Add("country", [string]) | Out-Null
    $dataTable.Columns.Add("state", [string]) | Out-Null
    $dataTable.Columns.Add("city", [string]) | Out-Null
    $dataTable.Columns.Add("buildingName", [string]) | Out-Null
    $dataTable.Columns.Add("address1", [string]) | Out-Null
    $dataTable.Columns.Add("address2", [string]) | Out-Null
    $dataTable.Columns.Add("address3", [string]) | Out-Null
    $dataTable.Columns.Add("address4", [string]) | Out-Null
    $dataTable.Columns.Add("postalCode", [string]) | Out-Null
    $dataTable.Columns.Add("floor", [string]) | Out-Null
    $dataTable.Columns.Add("users", [array]) | Out-Null
    $dataTable.Columns.Add("devices", [array]) | Out-Null

    foreach ($Row in $ServiceNowDataTable) {

        $NewRow = $null
        $NewRow = $dataTable.NewRow()
        $NewRow.uniqueIdentifier = $Row.sys_id
        $NewRow.name = $Row.name
        $NewRow.country = $Row.country
        $NewRow.state = $Row.state
        $NewRow.city = $Row.city
        $NewRow.address1 = $Row.street
        $NewRow.postalCode = $Row.zip

        $AddUsers = @()

        if ($UserDataTable -and $UserFeedId) {
            foreach ($user in $UserDataTable.Select("location_link='$($row.sys_id)'")) {
                $username = ("/imports/users/{0}/items/{1}" -f $UserFeedId, $user.user_name)
                $AddUsers += $username
            }
        }
        $NewRow.users = $AddUsers

        $AddDevices = @()
        if ($DeviceDataTable -and $DeviceFeedId) {
            foreach ($device in $DeviceDataTable.Select("location_link='$($row.sys_id)'")) {
                $devicelink = ("/imports/devices/{0}/items/{1}" -f $DeviceFeedId, $device.sys_id)
                $AddDevices += $devicelink
            }
        }
        $NewRow.devices = $AddDevices

        $dataTable.Rows.Add($NewRow)
    }

    Write-Debug ("INFO: Finished conversion for cmn_location to the Juriba DPC location import format.")
    Return ,$dataTable
}
