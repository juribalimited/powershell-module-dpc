 <#
    .Synopsis
    Pulls user data from Get-ADUser and upload to a DW User feed
   
    .Description
    Takes all users from Get-ADUser (optional server/cred parameters) transforms the fields into a datatable in the format required
    for the DW API and then uploads that user data to a named or numbered data feed.

    .Parameter Instance
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for and used. If this does not exist, it will create it.

    .Parameter ADServer
    The name of a DC to connect Get-ADUser to, including the port number. e.g. 389.

    .Parameter Credentials
    The credentials to use when calling Get-ADUser (optional)

    .Outputs
    Output type [string]
    Text confirming the number of rows to be inserted.

    .Example
    # Get the device feed id for the named feed.
    Invoke-DwAPIAUploadUserFeedFromAD -Instance $Instance -APIKey $APIKey -FeedName "AD Users"

    #>

    [CmdletBinding()]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,
        [Parameter(Mandatory=$True)]
        [string]$APIKey,
        [parameter(Mandatory=$True)]
        [string]$FeedName,     
        [Parameter(Mandatory=$true)]
        [string]$ADServer,
        [parameter(Mandatory=$False)]
        [System.Management.Automation.PSCredential]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    #Requires -Version 7
    #Requires -Module Juriba.Dashworks

    $DashworksParams = @{
        Instance = $Instance
        APIKey = $APIKey
    }

    # Get DW feed
    $feed = Get-DwImportUserFeed @DashworksParams -Name $FeedName
    # If it doesnt exist, create it
    if (-Not $feed) {
        $feed = New-DwImportUserFeed @DashworksParams -Name $FeedName -Enabled $true
    }
    $importId = $feed.id

    Write-Information ("Using feed id {0}" -f $importId) -InformationAction Continue

    $Properties = @("lastlogontimestamp","description","homeDirectory","homeDrive","mail","CanonicalName")

    if ($ADServer)
    {
        if ($Credential -ne [System.Management.Automation.PSCredential]::Empty)
        {
            $ADUsers = get-aduser -Filter * -Properties $properties -Server $ADServer -Credential $Credential
        }
        else
        {
            $ADUsers = get-aduser -Filter * -Properties $properties -Server $ADServer
        }
    }else{
        if ($Credential -ne [System.Management.Automation.PSCredential]::Empty)
        {
            $ADUsers = get-aduser -Filter * -Properties $properties -Credential $Credential
        }
        else
        {
            $ADUsers = get-aduser -Filter * -Properties $properties
        }
    }

    $dataTable = New-Object System.Data.DataTable

    $dataTable.Columns.Add("username", [string]) | Out-Null
    $dataTable.Columns.Add("commonObjectName", [string]) | Out-Null
    $dataTable.Columns.Add("displayName", [string]) | Out-Null
    $dataTable.Columns.Add("objectSid", [string]) | Out-Null
    $dataTable.Columns.Add("objectGuid", [string]) | Out-Null
    $dataTable.Columns.Add("lastLogonDate", [datetime]) | Out-Null
    $dataTable.Columns.Add("disabled", [string]) | Out-Null
    $dataTable.Columns.Add("surname", [string]) | Out-Null
    $dataTable.Columns.Add("givenName", [string]) | Out-Null
    $dataTable.Columns.Add("description", [string]) | Out-Null
    $dataTable.Columns.Add("homeDirectory", [string]) | Out-Null
    $dataTable.Columns.Add("homeDrive", [string]) | Out-Null
    $dataTable.Columns.Add("emailAddress", [string]) | Out-Null
    $dataTable.Columns.Add("userPrincipalName", [string]) | Out-Null
    $dataTable.Columns.Add("adCanonicalName", [string]) | Out-Null

    foreach($User in $ADUsers)
    {
        $NewRow = $null
        $NewRow = $dataTable.NewRow()

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

        $dataTable.Rows.Add($NewRow)
    }


    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $DeleteHeaders = @{
        "X-API-KEY" = "$APIKey"
    }

    $uri = "{0}/apiv2/imports/users/{1}/items" -f $Instance, $ImportId

    #Prior to insert to the new User data, clear down the existing dataset.
    Invoke-RestMethod -Headers $DeleteHeaders -Uri $uri -Method Delete

    $RowCount = 0
    foreach($Row in $dataTable)
    {
        $Body = $null
        $Body = $Row | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
        Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $Body | out-null
        $RowCount++
    }

    Return "$RowCount users added"