#requires -Version 7
function Get-DwApplicationV1 {
    <#
        .SYNOPSIS
        Gets Dashworks application from V1 API.

        .DESCRIPTION
        Gets Dashworks application from V1 API.

        .PARAMETER Filter

        Filter for application search.

        .PARAMETER Instance

        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .EXAMPLE
        PS> Get-DwImportApplication -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -ImportId 1 -InfoLevel "Full"

    #>
    param (
        [parameter(Mandatory=$false)]
        [string]$Filter,
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $limit = 5000
        $uri = "{0}/apiv1/applications" -f $Instance

        $uri += "?"
        $uri += $Filter
        $uri += "&limit={0}" -f $limit

        $headers = @{'x-api-key' = $APIKey}

        try {
            $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
            return (($result.content) | ConvertFrom-Json)
        }
        catch {
            if ($_.Exception.Response.StatusCode.Value__ -eq 404) {
                # 404 means the application was not found, don't treat this as an error
                # as we expect this function to be used to check if a application exists
                Write-Verbose "applications not found"
            }
            else {
                Write-Error $_
            }
        }
    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}