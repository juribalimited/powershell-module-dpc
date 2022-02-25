
function Get-DwAPIDeviceFeed {

    <#
    .Synopsis
    Returns the device feed id returned from the Dashworks API

    .Description
    Searches for, and allows for creation of, a Dashworks API device feed by the name of the feed.

    .Parameter APIUri
    The URI to the Dashworks instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter FeedName
    The name of the feed to be searched for.

    .Parameter Create
    A boolean to determine if the device feed should be created if it is not found.

    .Outputs
    Output type [int]
    The id of the device feed found or created. Empty otherwise.

    .Example
    # Get the device feed id for the named feed.
    $DeviceImportID = Get-DeviceFeed -APIUri $uriRoot -FeedName 'Test Device feed' -APIKey $APIKey -Create $true
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

    $uri = "$uriRoot/apiv2/imports/devices"

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

        $uri = "$APIUri/apiv2/imports/devices"
        $FeedDetails = Invoke-RestMethod -Headers $Postheaders -Uri $uri -Method Post -Body $Body
    }

    return $FeedDetails.id
}