#requires -Version 7
function Export-JuribaListDefinition {
    <#
        .SYNOPSIS
        Exports dynamic list definitions so they can be imported into another Juriba DPC instance.

        .DESCRIPTION
        Exports the definitions of dynamic lists (Dynamic and Dynamic Pivot) for devices, users,
        applications and mailboxes, using the Juriba DPC API v1. Use Import-JuribaListDefinition to
        create the lists on another instance.

        A list's queryString refers to many fields and filter values by IDs that are different on
        every instance, for example custom fields, projects, tasks, rings, buckets, paths, readiness,
        departments, imports and other lists. The export records how to find each of these on another
        instance: fields and filters by their Signature (see Get-JuribaListField and
        Get-JuribaListFilter) and ID-valued filter values by their display text.

        Lists used by a "Saved List" filter are exported too, so they can be created first on the
        target. Use -ExcludeDependencies to export only the lists you name; the import then expects
        a list with the same name to exist on the target.

        Static lists, association lists and list sharing permissions are not exported.

        The result is an object; save it with ConvertTo-Json -Depth 10 (see the example).

        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ListId
        Ids of the lists to export.

        .PARAMETER ListName
        Names of the lists to export. Must match exactly (case-insensitive).

        .PARAMETER All
        Export every dynamic list of the given object types.

        .PARAMETER ObjectType
        Object type of the lists. One or more of Device, User, Application, Mailbox. With -All, defaults to all four.

        .PARAMETER ExcludeDependencies
        Do not export lists that are only included because a "Saved List" filter uses them.

        .OUTPUTS
        An export object with schemaVersion, exportedAt and lists.

        .EXAMPLE
        PS> Export-JuribaListDefinition -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -ObjectType Device -ListName "Windows 11 Ready" | ConvertTo-Json -Depth 10 | Set-Content -Path ".\lists.json"

        .EXAMPLE
        PS> Export-JuribaListDefinition -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -ObjectType Device -ListId 101, 102

        .EXAMPLE
        PS> Export-JuribaListDefinition -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -All
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "All", Justification = "Selects the All parameter set.")]
    [CmdletBinding(DefaultParameterSetName = "ById")]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true, ParameterSetName = "ById")]
        [int[]]$ListId,
        [Parameter(Mandatory = $true, ParameterSetName = "ByName")]
        [string[]]$ListName,
        [Parameter(Mandatory = $true, ParameterSetName = "All")]
        [switch]$All,
        [Parameter(Mandatory = $true, ParameterSetName = "ById")]
        [Parameter(Mandatory = $true, ParameterSetName = "ByName")]
        [Parameter(Mandatory = $false, ParameterSetName = "All")]
        [ValidateSet("Device", "User", "Application", "Mailbox")]
        [string[]]$ObjectType = @("Device", "User", "Application", "Mailbox"),
        [Parameter(Mandatory = $false)]
        [switch]$ExcludeDependencies
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if (-not ($APIKey -and $Instance)) {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
        return
    }

    $allTypes = @("Device", "User", "Application", "Mailbox")
    $connection = @{ Instance = $Instance; APIKey = $APIKey }

    # Every list the API key can see, by id. List ids are unique across object types.
    # Saved-list dependencies can be of any object type, so all four are loaded.
    $catalog = [System.Collections.Generic.Dictionary[int, object]]::new()
    foreach ($type in $allTypes) {
        try {
            foreach ($list in @(Get-JuribaList @connection -ObjectType $type)) {
                $catalog[[int]$list.listId] = [pscustomobject]@{ ObjectType = $type; List = $list }
            }
        }
        catch {
            Write-Error ("Failed to get {0} lists: {1}" -f $type, $_)
            return
        }
    }

    $isExportable = {
        param($entry)
        ($entry.List.listType -in @('Dynamic', 'Dynamic Pivot')) -and -not $entry.List.isAssociationList
    }

    # Work out which lists were asked for.
    $requested = [System.Collections.Generic.List[object]]::new()
    switch ($PSCmdlet.ParameterSetName) {
        "ById" {
            foreach ($id in $ListId) {
                if ($catalog.ContainsKey($id) -and $catalog[$id].ObjectType -in $ObjectType) {
                    $requested.Add($catalog[$id])
                }
                else {
                    Write-Warning ("List {0} was not found for object type {1}." -f $id, ($ObjectType -join ', '))
                }
            }
        }
        "ByName" {
            foreach ($name in $ListName) {
                $matched = @($catalog.Values | Where-Object { $_.ObjectType -in $ObjectType -and $_.List.listName -eq $name })
                if ($matched.Count -eq 0) {
                    Write-Warning ("List '{0}' was not found for object type {1}." -f $name, ($ObjectType -join ', '))
                }
                foreach ($m in $matched) { $requested.Add($m) }
            }
        }
        "All" {
            $catalog.Values | Where-Object { $_.ObjectType -in $ObjectType -and (& $isExportable $_) } |
                Sort-Object { [int]$_.List.listId } | ForEach-Object { $requested.Add($_) }
        }
    }

    # Field and filter metadata and filter options are large, so each is fetched once.
    $fieldCache = @{}
    $filterCache = @{}
    $optionCache = @{}
    $getFields = {
        param($type)
        if (-not $fieldCache.ContainsKey($type)) {
            Write-Verbose ("Getting {0} list fields" -f $type)
            $byToken = [System.Collections.Generic.Dictionary[string, object]]::new()
            foreach ($f in @(Get-JuribaListField @connection -ObjectType $type -ErrorAction Stop)) { $byToken[$f.Token] = $f }
            $fieldCache[$type] = $byToken
        }
        $fieldCache[$type]
    }
    $getFilters = {
        param($type)
        if (-not $filterCache.ContainsKey($type)) {
            Write-Verbose ("Getting {0} list filters" -f $type)
            $byToken = [System.Collections.Generic.Dictionary[string, object]]::new()
            foreach ($f in @(Get-JuribaListFilter @connection -ObjectType $type -ErrorAction Stop)) { $byToken[$f.Token] = $f }
            $filterCache[$type] = $byToken
        }
        $filterCache[$type]
    }
    # Each filter's options, indexed by value, and whether the values are IDs rather than text.
    # Only ID-valued filters need mapping. Where every option's value is its own text (e.g. OS
    # names) the value is portable as-is.
    $getOptions = {
        param($optionsUrl)
        if (-not $optionCache.ContainsKey($optionsUrl)) {
            $byValue = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $idValued = $false
            foreach ($option in @(Get-JuribaListFilterOption @connection -OptionsUrl $optionsUrl -ErrorAction Stop)) {
                if (-not $byValue.ContainsKey([string]$option.Value)) { $byValue[[string]$option.Value] = $option }
                if ($option.Value -ne 'NULL' -and $option.Value -cne $option.Text) { $idValued = $true }
            }
            $optionCache[$optionsUrl] = [pscustomobject]@{ ByValue = $byValue; IdValued = $idValued }
        }
        $optionCache[$optionsUrl]
    }

    $exported = [System.Collections.Generic.Dictionary[int, object]]::new()
    $exportOrder = [System.Collections.Generic.List[int]]::new()
    $queue = [System.Collections.Generic.Queue[object]]::new()
    foreach ($entry in $requested) {
        if (-not (& $isExportable $entry)) {
            Write-Warning ("Skipping '{0}' ({1}): only dynamic lists that are not association lists can be exported." -f $entry.List.listName, $entry.List.listType)
            continue
        }
        $queue.Enqueue($entry)
    }

    # A failure on one list (e.g. an options call that errors) skips that list, not the whole export.
    $failed = [System.Collections.Generic.HashSet[int]]::new()
    while ($queue.Count -gt 0) {
        $entry = $queue.Dequeue()
        $list = $entry.List
        $id = [int]$list.listId
        if ($exported.ContainsKey($id) -or $failed.Contains($id)) { continue }
        try {
            $fields = & $getFields $entry.ObjectType
            $filters = & $getFilters $entry.ObjectType
            $parameters = @(ConvertFrom-JuribaListQueryString -QueryString ([string]$list.queryString))

            $columnRefs = [System.Collections.Generic.List[object]]::new()
            $columnSeen = [System.Collections.Generic.HashSet[string]]::new()
            $filterRefs = [System.Collections.Generic.List[object]]::new()
            $filterByToken = [System.Collections.Generic.Dictionary[string, object]]::new()
            $dependsOn = [System.Collections.Generic.List[int]]::new()

            foreach ($p in $parameters) {
                foreach ($segment in $p.Segments) {
                    if ($segment.Kind -eq 'Column') {
                        if (-not $columnSeen.Add($segment.Text)) { continue }
                        $field = if ($fields.ContainsKey($segment.Text)) { $fields[$segment.Text] } else { $null }
                        if (-not $field) {
                            Write-Warning ("List '{0}': column '{1}' was not found on this instance; the list may be broken." -f $list.listName, $segment.Text)
                        }
                        $columnRefs.Add([pscustomobject][ordered]@{
                            token     = $segment.Text
                            signature = if ($field) { $field.Signature } else { $null }
                        })
                    }
                    elseif ($segment.Kind -eq 'Filter') {
                        if ($filterByToken.ContainsKey($segment.Text)) { continue }
                        $filter = if ($filters.ContainsKey($segment.Text)) { $filters[$segment.Text] } else { $null }
                        if (-not $filter) {
                            Write-Warning ("List '{0}': filter '{1}' was not found on this instance; the list may be broken." -f $list.listName, $segment.Text)
                        }
                        $ref = [pscustomobject]@{
                            Token      = $segment.Text
                            Filter     = $filter
                            ValueRefs  = [System.Collections.Generic.List[object]]::new()
                            ValuesSeen = [System.Collections.Generic.HashSet[string]]::new()
                        }
                        $filterByToken[$segment.Text] = $ref
                        $filterRefs.Add($ref)
                    }
                    elseif ($segment.Kind -eq 'Value') {
                        if (-not $filterByToken.ContainsKey($segment.Field)) { continue }
                        $ref = $filterByToken[$segment.Field]
                        $filter = $ref.Filter
                        if (-not $filter -or $segment.Text -eq 'NULL' -or -not $ref.ValuesSeen.Add($segment.Text)) { continue }
                        if ([string]$filter.OptionsUrl -notmatch '/filters/options/') { continue }

                        $options = & $getOptions $filter.OptionsUrl
                        if (-not ($filter.IsSavedListFilter -or $options.IdValued)) { continue }

                        $option = if ($options.ByValue.ContainsKey($segment.Text)) { $options.ByValue[$segment.Text] } else { $null }
                        if (-not $option) {
                            Write-Warning ("List '{0}': value '{1}' of filter '{2}' was not found on this instance; the list may be broken." -f $list.listName, $segment.Text, $filter.Name)
                        }
                        $ref.ValueRefs.Add([pscustomobject][ordered]@{
                            value = $segment.Text
                            text  = if ($option) { $option.Text } else { $null }
                            path  = if ($option) { $option.Path } else { $null }
                        })

                        if ($filter.IsSavedListFilter -and $segment.Text -match '^\d+$') {
                            $depId = [int]$segment.Text
                            if (-not $ExcludeDependencies -and $catalog.ContainsKey($depId) -and (& $isExportable $catalog[$depId])) {
                                if (-not $dependsOn.Contains($depId)) { $dependsOn.Add($depId) }
                                if (-not $exported.ContainsKey($depId)) { $queue.Enqueue($catalog[$depId]) }
                            }
                        }
                    }
                }
            }

            $exported[$id] = [pscustomobject][ordered]@{
                sourceListId = $id
                listName     = $list.listName
                objectType   = $entry.ObjectType
                listType     = $list.listType
                queryString  = [string]$list.queryString
                columns      = $columnRefs.ToArray()
                filters      = @($filterRefs | ForEach-Object {
                    [pscustomobject][ordered]@{
                        token     = $_.Token
                        signature = if ($_.Filter) { $_.Filter.Signature } else { $null }
                        values    = $_.ValueRefs.ToArray()
                    }
                })
                dependsOn    = $dependsOn.ToArray()
            }
            $exportOrder.Add($id)
        }
        catch {
            [void]$failed.Add($id)
            Write-Warning ("List '{0}' ({1}) was not exported: {2}" -f $list.listName, $id, $_)
        }
    }

    # Order so that every list comes after the lists it depends on.
    $ordered = [System.Collections.Generic.List[object]]::new()
    $state = @{}
    $visit = {
        param([int]$id)
        if ($state[$id] -eq 'done') { return }
        if ($state[$id] -eq 'visiting') {
            Write-Warning ("Lists depend on each other in a loop (list {0}); import order may not satisfy every dependency." -f $id)
            return
        }
        $state[$id] = 'visiting'
        foreach ($dep in $exported[$id].dependsOn) {
            if ($exported.ContainsKey($dep)) { & $visit $dep }
        }
        $state[$id] = 'done'
        $ordered.Add($exported[$id])
    }
    foreach ($id in $exportOrder) { & $visit $id }

    return [pscustomobject][ordered]@{
        schemaVersion = 1
        exportedAt    = (Get-Date).ToUniversalTime().ToString('o')
        lists         = $ordered.ToArray()
    }
}
