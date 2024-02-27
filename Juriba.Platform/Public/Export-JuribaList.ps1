function Export-JuribaList {
    [alias("Export-DwList")]
    <#
        .SYNOPSIS
        Returns an Evergreen List as an array.

        .DESCRIPTION
        Returns an Evergreen List as an array.
        Takes ListId and ObjectType as an input

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ListId

        ListId of the list to be exported.

        .PARAMETER ObjectType

        Object type of the list. One of Device, User, Application, Mailbox

        .PARAMETER PageSize
        When a value greater than 0 is provided for the PageSize parameter, 
        the function constructs the API request URI to include query parameters that limit the number of items returned ($top) and specify the offset for the items to be fetched ($skip). 

        .EXAMPLE

        PS> Export-JuribaList -ListId 1234 -ObjectType Device -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx"
        Export-JuribaList -ListId 1234 -ObjectType Device -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -PageSize 100

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
        [string]$ObjectType,
        [Parameter(Mandatory=$false)]
        [int]$PageSize
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
        if ($PageSize -gt 0)
        {
            $uri = '{0}/apiv1/{1}?$top={2}&$skip=0&$listid={3}' -f $Instance, $path, $PageSize ,$ListId
        }
        else
        {
            $uri = '{0}/apiv1/{1}?$listid={2}' -f $Instance, $path, $ListId
        }
        $headers = @{'x-api-key' = $APIKey}

        try {
            $response = Invoke-WebRequest -uri $uri -Headers $headers -Method GET
            $results = ($response.Content | ConvertFrom-Json).results
            $metadata = ($response.Content | ConvertFrom-Json).metadata

            if($metadata.count -gt $PageSize -and $PageSize -gt 0)
            {
                #More rows to process
                for($i=1 ;$i -le [Math]::Floor(($metadata.count)/$PageSize);$i++)
                {
                    $uri = '{0}/apiv1/{1}?$top={2}&$skip={3}&keySetID={4}&$listid={5}' -f $Instance, $path, $PageSize, ($PageSize*$i), ($metadata.keySetId), $ListId
                    $response = Invoke-WebRequest -uri $uri -Headers $headers -Method GET
                    $results += ($response.Content | ConvertFrom-Json).results
                }
            }


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
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
