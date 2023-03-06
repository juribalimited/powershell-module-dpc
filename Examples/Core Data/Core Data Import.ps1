 <#
    .SYNOPSIS
    A sample script to create Devices from SCCM and Users, Locations and Departments from AD using Get-ADUser. Also links Users to Locations and Departments.
   
    .DESCRIPTION
    Takes all users from Get-ADUser (optional server/cred parameters) transforms the fields into a datatable in the format required
    for the DW API and then uploads that user data to a named or numbered data feed.

    .Parameter Instance
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter XXXFeedName
    The name of the feed to be searched for and used. If this does not exist, it will create it.

    .Parameter MecmServerInstance
    The name of the MECM server to be queried.

    .Parameter MecmDatabaseName
    The root database name on the MECM server, e.g. CM_XX

    .Parameter ADServer
    The name of a DC to connect Get-ADUser to, including the port number. e.g. 389.

    .Parameter Credentials
    The credentials to use when calling Get-ADUser (optional)

    .Outputs
    Output type [string]
	Text confirming the number of rows to be inserted.
 #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True)]
        [string]$Instance,
        [Parameter(Mandatory=$True)]
        [string]$APIKey,
        [Parameter(Mandatory=$True)]
        [string]$UserFeedName,
        [Parameter(Mandatory=$True)]
        [string]$DeviceFeedName,
        [parameter(Mandatory=$True)]
        [string]$LocationFeedName,
        [parameter(Mandatory=$True)]
        [string]$DepartmentFeedName,
        [Parameter(Mandatory=$true)]
        [string]$MecmServerInstance,
        [Parameter(Mandatory=$true)]
        [string]$MecmDatabaseName,
        [Parameter(Mandatory=$true)]
        [pscredential]$MecmCredentials,
        [Parameter(Mandatory=$true)]
        [string]$ADServer,
        [Parameter(Mandatory=$False)]
        [System.Management.Automation.PSCredential]$ADCredential = [System.Management.Automation.PSCredential]::Empty
    )

    #Requires -Version 7
    #Requires -Module Juriba.Dashworks

    $ErrorActionPreference = 'Continue'
    Function Get-StringHash{
        [OutputType([String])]
        Param (
            [parameter(Mandatory=$True)]
            [string]$StringToHash
            )
    
        $stringAsStream = [System.IO.MemoryStream]::new()
        $writer = [System.IO.StreamWriter]::new($stringAsStream)
        $writer.write($StringToHash)
        $writer.Flush()
        $stringAsStream.Position = 0
        return (Get-FileHash -InputStream $stringAsStream | Select-Object -property Hash).Hash
    }

    $DashworksParams = @{
        Instance = $Instance
        APIKey = $APIKey
    }

    Write-Information ("***** Importing Users, Locations & Departments *****") -InformationAction Continue

    # Get DW feed
    $feed = Get-DwImportUserFeed @DashworksParams -Name $UserFeedName
    # If it doesnt exist, create it
    if (-Not $feed) {
        $feed = New-DwImportUserFeed @DashworksParams -Name $UserFeedName -Enabled $true
    }
    $UserImportId = $feed.id

    Write-Information ("**************************") -InformationAction Continue
    Write-Information ("Using User feed - $UserFeedName") -InformationAction Continue
    Write-Information ("**************************") -InformationAction Continue

    $Properties = @("lastlogontimestamp","description","homeDirectory","homeDrive","mail","CanonicalName","StreetAddress","City","State","PostalCode","co","Department","Company")

    $UserDataTable = New-Object System.Data.DataTable
    $UserDataTable.Columns.Add("username", [string]) | Out-Null
    $UserDataTable.Columns.Add("commonObjectName", [string]) | Out-Null
    $UserDataTable.Columns.Add("displayName", [string]) | Out-Null
    $UserDataTable.Columns.Add("objectSid", [string]) | Out-Null
    $UserDataTable.Columns.Add("objectGuid", [string]) | Out-Null
    $UserDataTable.Columns.Add("lastLogonDate", [datetime]) | Out-Null
    $UserDataTable.Columns.Add("disabled", [string]) | Out-Null
    $UserDataTable.Columns.Add("surname", [string]) | Out-Null
    $UserDataTable.Columns.Add("givenName", [string]) | Out-Null
    $UserDataTable.Columns.Add("description", [string]) | Out-Null
    $UserDataTable.Columns.Add("homeDirectory", [string]) | Out-Null
    $UserDataTable.Columns.Add("homeDrive", [string]) | Out-Null
    $UserDataTable.Columns.Add("emailAddress", [string]) | Out-Null
    $UserDataTable.Columns.Add("userPrincipalName", [string]) | Out-Null
    $UserDataTable.Columns.Add("adCanonicalName", [string]) | Out-Null
    $UserDataTable.Columns.Add("StreetAddress", [string]) | Out-Null
    $UserDataTable.Columns.Add("City", [string]) | Out-Null
    $UserDataTable.Columns.Add("State", [string]) | Out-Null
    $UserDataTable.Columns.Add("PostalCode", [string]) | Out-Null
    $UserDataTable.Columns.Add("co", [string]) | Out-Null
    $UserDataTable.Columns.Add("Department", [string]) | Out-Null
    $UserDataTable.Columns.Add("Company", [string]) | Out-Null

    if ($ADServer)
    {
        if ($ADCredential -ne [System.Management.Automation.PSCredential]::Empty)
        {
            Get-ADUser -Filter * -Properties $properties -Server $ADServer -Credential $ADCredential | Foreach-Object {
                $User=$_
                $NewRow = $null
                $NewRow = $UserDataTable.NewRow()
                $NewRow.username = $User.SamAccountName
                $NewRow.commonObjectName = $User.CN
                $NewRow.displayName = $User.Name
                $NewRow.objectSid = $User.sid
                $NewRow.objectGuid = $User.objectGuid
                $NewRow.lastLogonDate = if ([datetime]::FromFileTime($User.lastlogontimestamp) -gt '1753-01-01'){[datetime]::FromFileTime($User.lastlogontimestamp)}else{[DBNull]::Value}
                $NewRow.disabled = -not $User.Enabled
                $NewRow.surname = $User.surname
                $NewRow.givenName = $User.givenName
                $NewRow.description = $User.Description
                $NewRow.homeDirectory = $User.homeDirectory
                $NewRow.homeDrive = $User.homeDrive
                $NewRow.emailAddress = $User.mail
                $NewRow.userPrincipalName = $User.userPrincipalName
                $NewRow.adCanonicalName = $User.CanonicalName
                $NewRow.StreetAddress = $User.StreetAddress
                $NewRow.City = $User.City
                $NewRow.State = $User.State
                $NewRow.PostalCode = $User.PostalCode
                $NewRow.co = $User.co
                $NewRow.Department = $User.Department
                $NewRow.Company = $User.Company
                $UserDataTable.Rows.Add($NewRow)
            }
        }
        else
        {
            Get-ADUser -Filter * -Properties $properties -Server $ADServer | Foreach-Object {
                $User=$_
                $NewRow = $null
                $NewRow = $UserDataTable.NewRow()
                $NewRow.username = $User.SamAccountName
                $NewRow.commonObjectName = $User.CN
                $NewRow.displayName = $User.Name
                $NewRow.objectSid = $User.sid
                $NewRow.objectGuid = $User.objectGuid
                $NewRow.lastLogonDate = if ([datetime]::FromFileTime($User.lastlogontimestamp) -gt '1753-01-01'){[datetime]::FromFileTime($User.lastlogontimestamp)}else{[DBNull]::Value}
                $NewRow.disabled = -not $User.Enabled
                $NewRow.surname = $User.surname
                $NewRow.givenName = $User.givenName
                $NewRow.description = $User.Description
                $NewRow.homeDirectory = $User.homeDirectory
                $NewRow.homeDrive = $User.homeDrive
                $NewRow.emailAddress = $User.mail
                $NewRow.userPrincipalName = $User.userPrincipalName
                $NewRow.adCanonicalName = $User.CanonicalName
                $NewRow.StreetAddress = $User.StreetAddress
                $NewRow.City = $User.City
                $NewRow.State = $User.State
                $NewRow.PostalCode = $User.PostalCode
                $NewRow.co = $User.co
                $NewRow.Department = $User.Department
                $NewRow.Company = $User.Company
                $UserDataTable.Rows.Add($NewRow)
            }
        }
    }else{
        if ($ADCredential -ne [System.Management.Automation.PSCredential]::Empty)
        {
            $ADUsers = Get-ADUser -Filter * -Properties $properties -Credential $ADCredential
        }
        else
        {
            $ADUsers = Get-ADUser -Filter * -Properties $properties
        }

        Foreach($User in $ADUsers)
        {
            $NewRow = $null
            $NewRow = $UserDataTable.NewRow()
            $NewRow.username = $User.SamAccountName
            $NewRow.commonObjectName = $User.CN
            $NewRow.displayName = $User.Name
            $NewRow.objectSid = $User.sid
            $NewRow.objectGuid = $User.objectGuid
            $NewRow.lastLogonDate = if ([datetime]::FromFileTime($User.lastlogontimestamp) -gt '1753-01-01'){[datetime]::FromFileTime($User.lastlogontimestamp)}else{[DBNull]::Value}
            $NewRow.disabled = -not $User.Enabled
            $NewRow.surname = $User.surname
            $NewRow.givenName = $User.givenName
            $NewRow.description = $User.Description
            $NewRow.homeDirectory = $User.homeDirectory
            $NewRow.homeDrive = $User.homeDrive
            $NewRow.emailAddress = $User.mail
            $NewRow.userPrincipalName = $User.userPrincipalName
            $NewRow.adCanonicalName = $User.CanonicalName
            $NewRow.StreetAddress = $User.StreetAddress
            $NewRow.City = $User.City
            $NewRow.State = $User.State
            $NewRow.PostalCode = $User.PostalCode
            $NewRow.co = $User.co
            $NewRow.Department = $User.Department
            $NewRow.Company = $User.Company
            $UserDataTable.Rows.Add($NewRow)
        }
    }

    #Userdata rows count
    $UDCount = $UserDataTable.rows.count
    Write-Host "$UDCount rows added to AD data table"

    $Locations = @()
    $UserLocations = @{}

    foreach($User in $UserDataTable)
    {
        $uniqueIdentifier=$null
        if ("$($User.StreetAddress)$($User.City)$($User.State)$($User.PostalCode)$($User.co)" -ne "")
        {

            $uniqueIdentifier = Get-StringHash -StringToHash "$($User.StreetAddress)$($User.City)$($User.State)$($User.PostalCode)$($User.co)"

            if ($null -eq $Locations.uniqueidentifier -or (-not $Locations.uniqueidentifier.contains($uniqueIdentifier)))
            {
                $Location = New-Object PSObject
                $Location | Add-Member -type NoteProperty -Name 'uniqueIdentifier' -Value $uniqueIdentifier
                $Location | Add-Member -type NoteProperty -Name 'name' -Value $(if ($User.StreetAddress -eq [DBNULL]::Value){if ($User.StreetAddress -like '*`n*'){($User.StreetAddress -split "`n")[0]}else{$User.StreetAddress}}else{$User.City})
                $Location | Add-Member -type NoteProperty -Name 'region' -Value "No Region Data"
                $Location | Add-Member -type NoteProperty -Name 'country' -Value $User.co
                $Location | Add-Member -type NoteProperty -Name 'state' -Value $User.State
                $Location | Add-Member -type NoteProperty -Name 'city' -Value $User.City
                $Location | Add-Member -type NoteProperty -Name 'buildingName' -Value $(if ($User.StreetAddress -like '*`n*'){($User.StreetAddress -split "`n")[0]}else{$User.StreetAddress})
                $Location | Add-Member -type NoteProperty -Name 'address1' -Value $(if ($User.StreetAddress -like '*`n*'){($User.StreetAddress -split "`n")[0]}else{$User.StreetAddress})
                $Location | Add-Member -type NoteProperty -Name 'address2' -Value $(if ($User.StreetAddress -like '*`n*'){($User.StreetAddress -split "`n")[1]}else{''})
                $Location | Add-Member -type NoteProperty -Name 'address3' -Value $(if ($User.StreetAddress -like '*`n*'){($User.StreetAddress -split "`n")[2]}else{''})
                $Location | Add-Member -type NoteProperty -Name 'address4' -Value $(if ($User.StreetAddress -like '*`n*'){($User.StreetAddress -split "`n")[3]}else{''})
                $Location | Add-Member -type NoteProperty -Name 'postalCode' -Value $User.PostalCode
                $Locations += $Location
            }
            $UserLocations.Add($($User.username),$uniqueIdentifier)
        }
    }

    $JsonLocationArray = @()

    foreach($Location in $Locations)
    {
        $LocUsers = @()
        foreach($User in $UserDataTable.Rows)
        {
            if($UserLocations[$($User.username)] -eq $Location.uniqueIdentifier)
            {
                $LocUsers += "/imports/users/$UserImportId/items/$($User.username)"
            }
        }
        $JSonObject = [pscustomobject]@{
            uniqueIdentifier = $Location.uniqueIdentifier
            name = $Location.name
            region = $Location.region
            country = $Location.country
            state = $Location.state
            city = $Location.city
            buildingName = $Location.buildingName
            address1 = $Location.address1
            address2 = $Location.address2
            address3 = $Location.address3
            address4 = $Location.address4
            postalCode = $Location.postalCode
            users = $LocUsers
        }
        $JsonLocationArray += $JSonObject | ConvertTo-Json -EscapeHandling EscapeNonAscii
    }

    #Locations rows count
    $LCount = $Locations.rows.count
    Write-Host "$LCount rows added to Locations data table"

    #Location User rows count
    $LUCount = $UserLocations.count
    Write-Host "$LUCount rows added to Location User data table"

    # Get DW Location feed
    $feed=$null
    $feed = Get-DwImportLocationFeed @DashworksParams -Name $LocationFeedName
    # If it doesnt exist, create it
    if (-Not $feed) {
        $feed = New-DwImportLocationFeed @DashworksParams -Name $LocationFeedName -Enabled $true
    }
    $LocationImportId = $feed.id

    $Departments = @()
    $UserDepartments = @{}

    foreach($User in $UserDataTable.Rows)
    {
        $uniqueIdentifier=$null
        $CompanyUID=$null

        if ("{0}{1}" -f $User.Company, $User.Department -ne "" -and $User.Department -ne [DBNull]::Value -and $User.Company -ne [DBNull]::Value)
        {
            $uniqueIdentifier = Get-StringHash -StringToHash "$($User.Company)#$($User.Department)"

            if ($User.Company -ne [DBNull]::Value)
            {
                $CompanyUID = Get-StringHash -StringToHash $($User.Company)
            }

            if ($null -eq $Departments.uniqueidentifier -or (-not $Departments.uniqueidentifier.contains($uniqueIdentifier)))
            {
                $Department = New-Object PSObject
                $Department | Add-Member -type NoteProperty -Name 'uniqueIdentifier' -Value $uniqueIdentifier
                $Department | Add-Member -type NoteProperty -Name 'Department' -Value $User.Department
                $Department | Add-Member -type NoteProperty -Name 'CompanyUID' -Value $CompanyUID
                $Department | Add-Member -type NoteProperty -Name 'Company' -Value $User.Company
                $Departments += $Department
            }
            $UserDepartments.Add($($User.Username),$uniqueIdentifier)
        }
    }

    $JsonDepartmentArray = @()
    $SeenCompanies = @()
    $SeenCompanies += ''
    
    foreach($Department in $Departments)
    {
        $DeptUsers = @()
        foreach($User in $UserDataTable.Rows)
        {
            if($UserDepartments[$($User.username)] -eq $Department.uniqueIdentifier)
            {
                $DeptUsers += "/imports/users/$UserImportID/items/$($User.username)"
            }
        }
        if (-not $SeenCompanies.Contains($Department.CompanyUID))
        {
            $JSonObject = [pscustomobject]@{
                uniqueIdentifier = $Department.CompanyUID
                name = $Department.Company
            }
            $JsonDepartmentArray += $JSonObject | ConvertTo-Json
            $SeenCompanies += $Department.CompanyUID
        }
        $JSonObject = [pscustomobject]@{
            uniqueIdentifier = $Department.uniqueIdentifier
            name = $Department.Department
            parentUniqueIdentifier = $Department.CompanyUID
            users = $DeptUsers
        }
        $JsonDepartmentArray += $JSonObject | ConvertTo-Json -EscapeHandling EscapeNonAscii
    }

    #Department rows count
    $DCount = $Departments.rows.count
    Write-Host "$DCount rows added to Department data table"

    #Department user rows count
    $DUCount = $UserDepartments.count
    Write-Host "$DUCount rows added to Department user data table"

    # Get DW Department feed
    $feed=$null
    $feed = Get-DwImportDepartmentFeed @DashworksParams -Name $DepartmentFeedName
    # If it doesnt exist, create it
    if (-Not $feed) {
        $feed = New-DwImportDepartmentFeed @DashworksParams -Name $DepartmentFeedName -Enabled $true
    }
    $DepartmentImportId = $feed.id


    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $DeleteHeaders = @{
        "X-API-KEY" = "$APIKey"
    }

    $uri = "{0}/apiv2/imports/users/{1}/items" -f $Instance, $UserImportId

    #Prior to insert to the new User data, clear down the existing dataset.
    Invoke-RestMethod -Headers $DeleteHeaders -Uri $uri -Method Delete

    $UserImported = @{}
    $UserDataTable | Foreach-Object {$UserImported.($_.username) = 0}
    $sync = [System.Collections.Hashtable]::Synchronized($UserImported)

    $UserDataTable | ForEach-Object -ThrottleLimit 30 -Parallel {
        function RetryCommand {

            Param([String] $CommandName,
                  [hashtable] $CommandArgs = @{},
                  [int] $MaxRetries=10,
                  [int] $SleepSeconds=2 )
        
            $retrycount = 0
            $CommandArgs.ErrorAction='Stop'
            while ($retrycount++ -lt $MaxRetries) {
        
                try {
        
                    &$CommandName @CommandArgs
                    return
                }
                catch {
        
                    Write-Error -ErrorRecord $_
                    Start-Sleep -Seconds $SleepSeconds
                }
            }
            throw "Max retries reached"
        }

        $syncCopy = $using:sync
        $Body = $null
        $Body = $_ | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors, StreetAddress, City, State, PostalCode, co, Department, Company | ConvertTo-Json -EscapeHandling EscapeNonAscii
        try{
            $CallParams = @{
                Headers = $using:Postheaders
                Uri = $using:uri
                Method = "Post"
                Body = $Body
            }
            RetryCommand Invoke-RestMethod $CallParams | out-null
            $syncCopy[$_.username] = 1
        }
        catch{
            Write-Output "The Location data has failed"
        }
    }

    $RowCount = $sync.GetEnumerator().Where({$_.value -eq 1}).count
    $FailedRowCount = $sync.GetEnumerator().Where({$_.value -eq 0}).count
    Write-Output "$FailedRowCount user rows have failed"

    Write-Output "$RowCount users added"

    ####################################
    # Add Locations

    $uri = "{0}/apiv2/imports/Locations/{1}/items" -f $Instance, $LocationImportID

    #Once the users are in, add the locations
    #Prior to insert to the Location data, clear down the existing data.
    Invoke-RestMethod -Headers $DeleteHeaders -Uri $uri -Method Delete
    
    foreach($Body in $JsonLocationArray)
    {
        try{
            Invoke-RestMethod -Headers $PostHeaders -Uri $uri -Method Post -Body $Body | out-null
        }
        catch{
            $Body
        }
    }

    ####################################
    # Add Departments


    $uri = "{0}/apiv2/imports/Departments/{1}/items" -f $Instance, $DepartmentImportID

    #Prior to insert to the Location data, clear down the existing data.
    Invoke-RestMethod -Headers $DeleteHeaders -Uri $uri -Method Delete
    
    foreach($Body in $JsonDepartmentArray)
    {
        try{
            Invoke-RestMethod -Headers $PostHeaders -Uri $uri -Method Post -Body $Body | out-null
        }
        catch{
            $Body
        }
    }

    ####################################
    # Add Devices

    Write-Information ("***** Importing MECM Devices *****") -InformationAction Continue
    
    $MecmParams = @{
        ServerInstance = $MecmServerInstance
        Database = $MecmDatabaseName
        Credential = $MecmCredentials
    }

    # Get DW feed
    $feed=$null
    $feed = Get-DwImportDeviceFeed @DashworksParams -Name $DeviceFeedName
    # If it doesnt exist, create it
    if (-Not $feed) {
        $feed = New-DwImportDeviceFeed @DashworksParams -Name $DeviceFeedName -Enabled $true
    }
    $DeviceImportId = $feed.id
    
    $uri=$null
    $uri = "{0}/apiv2/imports/Devices/{1}/items" -f $Instance, $DeviceImportId

    Write-Information ("**************************") -InformationAction Continue
    Write-Information ("Using Device feed - $DeviceFeedName") -InformationAction Continue
    Write-Information ("**************************") -InformationAction Continue

    # Run query against MECM database
    $table = Invoke-Sqlcmd @MecmParams -InputFile ".\MECM Device Query.sql"

    Write-Information ("MECM query returned {0} rows." -f $table.count) -InformationAction Continue

    #Prior to insert to the new User data, clear down the existing dataset.
    Invoke-RestMethod -Headers $DeleteHeaders -Uri $uri -Method Delete

    # build hashtable for job
    $origin = @{}
    $table | Foreach-Object {$origin.($_.uniqueIdentifier) = 0}

    # create synced hashtable
    $sync = [System.Collections.Hashtable]::Synchronized($origin)

    $ErrorActionPreference = 'SilentlyContinue'
    $table | ForEach-Object -ThrottleLimit 30 -Parallel {
        $syncCopy = $using:sync
        
        $uniqueIdentifier = $_.uniqueIdentifier
        $OwnerUsername = $_.OwnerUsername

        Import-Module Juriba.Dashworks
        # convert table row to json, exclude attributes we dont need
        $Body = $_ | Select-Object *,owner -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors, OwnerDomain, OwnerUsername

        if (($OwnerUsername) -and (($using:UserDataTable.Rows.Count) -gt 0))
        {
            #Set the Owner as the UPN rather than the id of the User
            $dvUserDataTable = New-Object System.Data.DataView($using:UserDataTable)
            $dvUserDataTable.RowFilter="username='$($OwnerUsername)'"
            if ($dvUserDataTable.username)
            {
                $Body.owner = "/imports/users/$using:UserImportID/items/$($dvUserDataTable.username)"
            }else{
                $Body.owner = $null
            }
        }else{
            $Body.owner = $null
        }
        $jsonBody = $Body | ConvertTo-Json -EscapeHandling EscapeNonAscii
       

        $existingDevice = Get-DwImportDevice @using:DashworksParams -ImportId $using:DeviceImportId -UniqueIdentifier $uniqueIdentifier


       if ($existingDevice) {
            $result = Set-DwImportDevice @using:DashworksParams -ImportId $using:DeviceImportId -UniqueIdentifier $uniqueIdentifier -JsonBody $jsonBody
            # check result, for an update we are expecting status code 204
            if ($result.StatusCode -ne 204) {
                Write-Error $result
            }
            else{
                $syncCopy[$_.uniqueIdentifier] = 1
            }
        }
        else {
            try{
                $result = New-DwImportDevice @using:DashworksParams -ImportId $using:DeviceImportId -JsonBody $jsonBody
                # check result, for a new device we expect the return object to contain the device
                if ($result -And -Not $result.uniqueIdentifier) {
                    Write-Error $result
                }
                $syncCopy[$_.uniqueIdentifier] = 1
            }
            catch{
                write-host $_
                write-host $jsonBody
            }
        }
    }

    $ErrorActionPreference = 'Continue'

    $RowCount = $sync.GetEnumerator().Where({$_.value -eq 1}).count
    $sync.GetEnumerator().Where({$_.value -eq 0}).count

    Write-Output "$RowCount devices added"

