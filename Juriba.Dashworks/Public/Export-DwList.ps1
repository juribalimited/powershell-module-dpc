function Export-DwList {
    <#
        .SYNOPSIS
        Returns an Evergreen List as an array.

        .DESCRIPTION
        Returns an Evergreen List as an array.
        Takes ListId and ObjectType as an input

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Dw. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Dw.

        .PARAMETER ListId

        ListId of the list to be exported.

        .PARAMETER ObjectType

        Object type of the list. One of Device, User, Application, Mailbox

        .EXAMPLE

        PS> Export-DwList -ListId 1234 -ObjectType Device -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$ListId,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox", "DeviceApplication", "UserApplication")]
        [string]$ObjectType
    )

    $path = switch($ObjectType) {
        "Device"            {"devices"}
        "User"              {"users"}
        "Application"       {"applications"}
        "Mailbox"           {"mailboxes"}
        "DeviceApplication" {"deviceapplications"}
        "UserApplication"   {"userapplications"}
    }

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $uri = '{0}/apiv1/{1}?$listid={2}' -f $Instance, $path, $ListId
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

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Dw before proceeding."
    }
}
