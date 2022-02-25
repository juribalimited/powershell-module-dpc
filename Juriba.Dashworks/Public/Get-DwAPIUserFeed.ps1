
function Get-DwAPIUserFeed {

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

    .Parameter Create
    A boolean to determine if the user feed should be created if it is not found.

    .Outputs
    Output type [int]
    The id of the user feed found or created. Empty otherwise.

    .Example
    # Get the user feed id for the named feed.
    $UserImportID = Get-DwAPIUserFeed -APIUri $uriRoot -FeedName 'Test User feed' -APIKey $APIKey -Create $true
    #>

    Param (
        [parameter(Mandatory=$True)]
        [string]$APIUri,

        [Parameter(Mandatory=$True)]
        [string]$APIKey,

        [parameter(Mandatory=$True)]
        [string]$FeedName,

        [Parameter(Mandatory=$False)]
        [bool]$Create = $False
    )

    $Getheaders =
    @{
        "accept" = "application/json"
        "X-API-KEY" = "$APIKey"
    }

    $uri = "$uriRoot/apiv2/imports/users"

    $uri += '?filter='
    $uri += [System.Web.HttpUtility]::UrlEncode("eq(name,'$FeedName')")

    $FeedDetails = Invoke-RestMethod -Headers $Getheaders -Uri $uri -Method Get

    if(-not $FeedDetails -and $Create)
    {
        $Params = @{
            "name" = $FeedName
            "enabled"  = "true"
        }

        $Postheaders =
        @{
            "content-type" = "application/json"
            "X-API-KEY" = "$APIKey"
        }
        $Body = $Params | ConvertTo-Json

        $uri = "$APIUri/apiv2/imports/users"
        $FeedDetails = Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $Body
    }

    return $FeedDetails.id
}
