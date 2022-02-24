function Export-DwList {
    <#
        .SYNOPSIS
        Returns an Evergreen List as an array.

        .DESCRIPTION
        Returns an Evergreen List as an array.
        Takes ListId and ObjectType as an input

        .PARAMETER Instance

        Dashworks instance. For example, myinstance.dashworks.app

        .PARAMETER Port

        Dashworks API port number. Default = 8443

        .PARAMETER APIKey

        Dashworks API Key.

        .PARAMETER ListId

        ListId of the list to be exported.

        .PARAMETER ObjectType

        Object type of the list. One of Device, User, Application, Mailbox

        .EXAMPLE

        PS> Export-DwList -ListId 1234 -ObjectType Device -Instance "myinstance.dashworks.app" -APIKey "xxxxx"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [int]$Port = 8443,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$ListId,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox")]
        [string]$ObjectType
    )

    $path = switch($ObjectType) {
        "Device"        {"devices"}
        "User"          {"users"}
        "Application"   {"applications"}
        "Mailbox"       {"mailboxes"}
    }

    $uri = 'https://{0}:{1}/apiv1/{2}?$listid={3}' -f $Instance, $Port, $path, $ListId
    $headers = @{'x-api-key' = $APIKey}

    try {
        $response = Invoke-WebRequest -uri $uri -Headers $headers -Method GET
        $results = ($response.Content | ConvertFrom-Json).results
        $metadata = ($response.Content | ConvertFrom-Json).metadata
        #check for an error in the metadata
        if ($metadata.errorMessage) {
            throw $metadata.errorMessage
        }
        #check for columns in metadata, missing columns indicates an issue with the list
        if (-not $metadata.columns) {
            throw "list did not return column metadata"
        }

        #build mapping using column headers from metadata and data from results
        $c = @()
        $metadata.columns | ForEach-Object {
            # handle readiness columns which return a nested object, here we are extracting the ragStatus (i.e. the name of the status)
            if ($_.displayType -eq "Readiness") {
                $cn = [scriptblock]::Create('$_.{0}.ragStatus' -f $_.columnName)
                $c += @{Name=$_.translatedColumnName; Expression=$cn}
            }
            else {
                $c += @{Name=$_.translatedColumnName; Expression=$_.columnName}
            }
        }
        #return results with mapped headers
        return ($results | Select-Object -Property $c)
    }
    catch {
        Write-Error $_
    }
}
