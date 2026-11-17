#requires -Version 7
function Get-JuribaListFilterOption {
    <#
        .SYNOPSIS
        Returns the values a list filter accepts.

        .DESCRIPTION
        Returns the values a Juriba DPC list filter accepts, using the Juriba DPC API v1. These are the
        options shown in the filter builder for filters such as rings, buckets, paths, readiness,
        task values, departments, imports and saved lists.

        Value is what is stored in a list's queryString. For many filters it is an ID that is different
        on every instance, while Text is the display name. For tree filters such as departments, Path
        holds the full path of names (for example "Sales \ Account Management"); for other filters Path
        is the same as Text.

        Use the OptionsUrl returned by Get-JuribaListFilter. Filters whose OptionsUrl does not point at a
        filters/options endpoint (for example date filters) have no fixed values and return nothing.

        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER OptionsUrl
        The OptionsUrl of a filter, as returned by Get-JuribaListFilter. For example /devices/filters/options/evergreenringid.
        Accepts pipeline input by property name.

        .OUTPUTS
        One object per option with Value, Text and Path.

        .EXAMPLE
        PS> Get-JuribaListFilterOption -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -OptionsUrl "/devices/filters/options/evergreenringid"

        .EXAMPLE
        PS> Get-JuribaListFilter -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -ObjectType Device -Name "Evergreen Ring" | Get-JuribaListFilterOption -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [AllowEmptyString()]
        [string]$OptionsUrl
    )

    begin {
        if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
            $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
            $Instance = $dwConnection.instance
        }
    }

    process {
        if (-not ($APIKey -and $Instance)) {
            Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
            return
        }

        if ($OptionsUrl -notmatch '/filters/options/') {
            Write-Verbose ("'{0}' is not a filter options endpoint; the filter has no fixed values." -f $OptionsUrl)
            return
        }

        $separator = if ($OptionsUrl.Contains('?')) { '&' } else { '?' }
        $uri = ("{0}/apiv1{1}{2}" -f $Instance, $OptionsUrl, $separator) + '$lang=en-US'
        $headers = @{'x-api-key' = $APIKey}

        try {
            $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
        }
        catch {
            Write-Error $_
            return
        }

        # Tree options (e.g. departments) use id/name/children; flat options use value/text.
        $walk = {
            param($node, [string[]]$path)
            $nodePath = $path + $node.name
            [pscustomobject]@{
                Value = [string]$node.id
                Text  = $node.name
                Path  = $nodePath -join ' \ '
            }
            foreach ($child in $node.children) {
                if ($child) { & $walk $child $nodePath }
            }
        }

        foreach ($option in $response) {
            if ($option.PSObject.Properties.Name -contains 'children') {
                & $walk $option @()
            }
            else {
                $text = if ($option.translatedText) { $option.translatedText } else { $option.text }
                [pscustomobject]@{
                    Value = [string]$option.value
                    Text  = $text
                    Path  = $text
                }
            }
        }
    }
}
