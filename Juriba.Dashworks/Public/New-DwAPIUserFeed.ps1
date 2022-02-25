function New-DwAPIUserFeed {

    <#
    .Synopsis
    Returns the user feed id returned from the Dashworks API

    .Description
    Searches for, and allows for creation of, a Dashworks API user feed by the name of the feed.

    .Parameter APIUri
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for.

    .Outputs
    Output type [int]
    The id of the user feed found or created. Empty otherwise.

    .Example
    # Get the user feed id for the named feed.
    $UserImportID = New-DwAPIUserFeed -APIUri $uriRoot -FeedName 'Test Device feed' -APIKey $APIKey
    #>

    Param (
        [parameter(Mandatory=$True)]
        [string]$APIUri,
        
        [Parameter(Mandatory=$True)]
        [PSObject]$APIKey,

        [parameter(Mandatory=$True,ValueFromPipeline = $True)]
        [string[]]$FeedName
    )

    return Get-DwAPIUserFeed -APIUri $APIUri -APIKey $APIKey -FeedName $Feedname -Create $True
    
}