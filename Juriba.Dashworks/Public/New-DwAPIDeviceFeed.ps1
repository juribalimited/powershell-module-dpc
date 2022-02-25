function New-DwAPIDeviceFeed {

    <#
    .Synopsis
    Returns the device feed id returned from the Dashworks API

    .Description
    Searches for, and allows for creation of, a Dashworks API device feed by the name of the feed.
    If the feed by that name exists, the import will return the ID of the feed rather than create it.

    .Parameter APIUri
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be created for.

    .Outputs
    Output type [int]
    The id of the device feed found or created. Empty otherwise.

    .Example
    # Get the device feed id for the named feed.
    $DeviceImportID = New-DwAPIDeviceFeed -APIUri $uriRoot -FeedName 'Test Device feed' -APIKey $APIKey
    #>

    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [parameter(Mandatory=$True)]
        [string]$APIUri,
        
        [Parameter(Mandatory=$True)]
        [PSObject]$APIKey,

        [parameter(Mandatory=$True,ValueFromPipeline = $True)]
        [string[]]$FeedName
    )
    if ($PSCmdlet.ShouldProcess("Create Device feed",$Feedname)) {
        return Get-DwAPIDeviceFeed -APIUri $APIUri -APIKey $APIKey -FeedName $Feedname -Create $True
    }
    
    
}