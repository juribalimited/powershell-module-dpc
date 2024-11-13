function Invoke-JuribaAPIImportLocationFeedDataTable{
    <#
    .Synopsis
    Loops a correctly formatted data table inserting all of the rows it contains.

    .Description
    Takes a System.Data.Datatable object with the columns required for the DwAPI user. Inserts these users one at a time.

    .Parameter Instance
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for and used.

    .Parameter ImportId
    The id of the user feed to be used.

    .Parameter DWDataTable
    [System.Data.DataTable] Data table containing the fields required to insert data into the DW user API.

    .Outputs
    Output type [string]
    Text confirming the number of rows to be inserted.
    #>

    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,

        [Parameter(Mandatory=$True)]
        [System.Data.DataTable]$DWLocationDataTable,

        [Parameter(Mandatory=$True)]
        [string]$APIKey,

        [parameter(Mandatory=$False)]
        [string]$FeedName = $null,

        [parameter(Mandatory=$False)]
        [string]$ImportId
    )


    if (-not $ImportId)
    {
        if (-not $FeedName)
        {
            return 'Location feed not found by name or ID'
        }

        try{
            $ImportId = (Get-JuribaImportLocationFeed -Instance $Instance -ApiKey $APIKey -Name $FeedName).id
        }
        catch {
            write-error "User feed lookup returned no results"
            exit 1
        }

        if (-not $ImportId)
        {
            return 'Location feed not found by name or ID'
        } else {
            
            $Deleteheaders = @{
                                "X-API-KEY" = "$APIKey"
                            }
            $Deleteuri = "{0}/apiv2/imports/locations/{1}/items" -f $Instance, $ImportId
            Invoke-RestMethod -Headers $Deleteheaders -Uri $Deleteuri -Method DELETE | out-null

            Write-Debug ("INFO: Deleted records for ImportID $ImportID, $Feedname")
        }
    }

    $Postheaders = @{
        "content-type" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = "{0}/apiv2/imports/locations/{1}/items" -f $Instance, $ImportId

    #$DWLocationDataTable | Foreach-Object -Parallel {
    #    $Row = $_
    foreach($Row in $DWLocationDataTable) {

        $Body = $null
        $Body = $Row | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
        #try{
            #Invoke-RestMethod -Headers $Using:Postheaders -Uri $Using:uri -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($Body)) | out-null
            Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($Body)) -AllowInsecureRedirect | out-null
        #}
        #catch{write-host "Location $($Row.uniqueIdentifier) Failed with Error: $($_.ErrorDetails)"}
        #$RowCount++
    }# -ThrottleLimit 25

    Return ("{0} locations sent" -f $DWLocationDataTable.Rows.Count)
}