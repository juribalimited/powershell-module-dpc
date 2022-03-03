#requires -Version 7
function Get-DwImportUserFeed {
    <#
        .SYNOPSIS
        Gets User imports.

        .DESCRIPTION
        Gets one or more User feeds.
        Use ImportId to get a specific feed or omit for all feeds.

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER ImportId

        Optional. The id for the User feed. Omit to get all User feeds.

        .PARAMETER FeedName

        Optional. Name of User feed to find. Can only be used when ImportId is not specified.

        .EXAMPLE

        PS> Get-DwImportUserFeed -ImportId 1 -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [parameter(Mandatory=$false, ParameterSetName="ImportId")]
        [int]$ImportId,
        [parameter(Mandatory=$false, ParameterSetName="Name")]
        [string]$Name
    )

    $uri = "{0}/apiv2/imports/devices" -f $Instance
    switch ($PSCmdlet.ParameterSetName){
        "ImportId" {
            $uri += "/{0}" -f $ImportId
        }
        "Name" {
            $uri += "?filter="
            $uri += [System.Web.HttpUtility]::UrlEncode("eq(name,'{0}')" -f $Name)
        }
    }

    $headers = @{'x-api-key' = $APIKey}

    try {
        $result = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
        return $result
    }
    catch {
        Write-Error $_
    }

}