function Convert-DwAPILocationFromServiceNowCMN_Location {
    [OutputType([System.Data.DataTable])]                                                                                                                                                                   
    Param(
        [Parameter(Mandatory=$True)]
        [System.Data.DataTable] $ServiceNowDataTable,
        [Parameter(Mandatory=$false)]
        [System.Data.DataTable] $UserDataTable,
        [Parameter(Mandatory=$false)]
        [string] $UserFeedId = 1,
        [System.Data.DataTable] $DeviceDataTable,
        [Parameter(Mandatory=$false)]
        [string] $DeviceFeedId = 1
    )
    
    <#
    .Synopsis
    Return a datatable in the DWAPI location data format from the Get-ServiceNowTable for cmn_location

    .Description
    Takes in a datatable returned from the Get-ServiceNowTable and strips the fields required for insertion into the Dashworks location API.

    .Parameter ServiceNowDataTable
    A System.Data.DataTable object returned from the Get-ServiceNowTable function

    .Outputs
    Output type [System.Data.DataTable]
    A table with the schema as used in the DW Users API calls populated with the provided data from serviceNow cmn_location.

    .Example
    # Convert the data for use in the DWAPI
    $dtDashworksInput = Convert-DwAPIlocationFromServiceNowCMN_location -SerivceNowDataTable $dtlocation
    #>
    Write-Host ("INFO: Starting conversion for cmn_location to DWAPI format.")

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
        #$NewRow.region = $Row
        $NewRow.country = $Row.country
        $NewRow.state = $Row.state
        $NewRow.city = $Row.city
        #$NewRow.buildingName = $Row.name
        $NewRow.address1 = $Row.street
        #$NewRow.address2 = $Row.name
        #$NewRow.address3 = $Row.name
        #$NewRow.address4 = $Row.name
        $NewRow.postalCode = $Row.zip
        #$NewRow.floor = $Row.

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
    
    Write-Host ("INFO: Finished conversion for cmn_location to DWAPI format.")
    Return ,$dataTable
}