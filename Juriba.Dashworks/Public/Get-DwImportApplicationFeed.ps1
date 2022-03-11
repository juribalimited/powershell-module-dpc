#requires -Version 7
function Get-DwImportApplicationFeed {
    <#
        .SYNOPSIS
        Gets application imports.
        .DESCRIPTION
        Gets one or more application feeds.
        Use ImportId to get a specific feed or omit for all feeds.
        .PARAMETER Instance
        Dashworks instance. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Dashworks API Key.
        .PARAMETER ImportId
        Optional. The id for the application feed. Omit to get all application feeds.
        .PARAMETER Name
        Optional. Name of application feed to find. Can only be used when ImportId is not specified.
        .EXAMPLE
        PS> Get-DwImportApplicationFeed -ImportId 1 -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"
        .EXAMPLE
        PS> Get-DwImportApplicationFeed -Name "My App Feed" -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"
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

    $uri = "{0}/apiv2/imports/applications" -f $Instance
    switch ($PSCmdlet.ParameterSetName) {
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