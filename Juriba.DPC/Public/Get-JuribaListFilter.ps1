#requires -Version 7
function Get-JuribaListFilter {
    <#
        .SYNOPSIS
        Returns the filters that can be used in a list for an object type.

        .DESCRIPTION
        Returns the filters that can be used in a Juriba DPC list, using the Juriba DPC API v1.
        This is the same set of filters the filter builder shows, including custom fields, project fields
        and project stage and task fields.

        Token is the value used for the filter in a list's queryString ($filter). Tokens for generated
        fields such as custom fields and projects contain IDs that are different on every instance.
        Signature identifies the same filter on another instance: it combines the category, subcategory,
        stage and task path, and display name.

        OptionsUrl, where it points at a filters/options endpoint, can be passed to
        Get-JuribaListFilterOption to get the values the filter accepts.

        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ObjectType
        Object type of the list. One of Device, User, Application, Mailbox.

        .PARAMETER Name
        Optional. Only return filters whose display name matches this value. Wildcards are supported.

        .OUTPUTS
        One object per filter with Token, Name, Category, SubCategory, Path, Type, OptionsUrl,
        IsSavedListFilter and Signature.

        .EXAMPLE
        PS> Get-JuribaListFilter -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -ObjectType Device

        .EXAMPLE
        PS> Get-JuribaListFilter -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -ObjectType Device -Name "*Ring*"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox")]
        [string]$ObjectType,
        [Parameter(Mandatory = $false)]
        [string]$Name
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $endpoint = switch ($ObjectType) {
            "Device"      { "devices" }
            "User"        { "users" }
            "Application" { "applications" }
            "Mailbox"     { "mailboxes" }
        }
        $uri = ("{0}/apiv1/{1}/filters" -f $Instance, $endpoint) + '?$lang=en-US'
        $headers = @{'x-api-key' = $APIKey}

        try {
            $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
        }
        catch {
            Write-Error $_
            return
        }

        $filters = [System.Collections.Generic.List[object]]::new()
        # Tree nodes do not all carry the same properties, so read them safely
        # under strict mode.
        $get = {
            param($object, [string]$property)
            $p = $object.PSObject.Properties[$property]
            if ($p) { $p.Value }
        }
        # Walks the stage and task tree. Containers are not selectable but their
        # names form the Path of the filters beneath them.
        $walk = {
            param($node, [string[]]$path)
            $id = & $get $node 'id'
            $label = & $get $node 'label'
            $nodeType = & $get $node 'nodeType'
            if ($id -and $id -ne 'stages_tasks' -and ($null -eq $nodeType -or (& $get $node 'isSelectable'))) {
                $category = [string](& $get $node 'category')
                $subCategory = (@(& $get $node 'translatedSubCategories') | Where-Object { $_ }) -join ' \ '
                $pathText = $path -join ' \ '
                $filters.Add([pscustomobject]@{
                    Token             = $id
                    Name              = $label
                    Category          = $category
                    SubCategory       = $subCategory
                    Path              = $pathText
                    Type              = & $get $node 'type'
                    OptionsUrl        = & $get $node 'optionsUrl'
                    IsSavedListFilter = [bool](& $get $node 'savedListFilter')
                    Signature         = ('{0}|{1}|{2}|{3}' -f $category, $subCategory, $pathText, $label)
                })
            }
            $children = & $get $node 'children'
            if ($children) {
                $childPath = if ($nodeType -and $nodeType -ne 'Root') { $path + $label } else { $path }
                foreach ($child in $children) {
                    if ($child) { & $walk $child $childPath }
                }
            }
        }
        foreach ($node in $response) {
            & $walk $node @()
        }

        if ($Name) {
            return ($filters | Where-Object { $_.Name -like $Name })
        }
        return $filters.ToArray()
    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
