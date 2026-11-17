#requires -Version 7
function Import-JuribaListDefinition {
    <#
        .SYNOPSIS
        Creates lists on a Juriba DPC instance from definitions exported with Export-JuribaListDefinition.

        .DESCRIPTION
        Creates dynamic lists from an export made by Export-JuribaListDefinition, using the Juriba DPC API v1.
        The export can come from a different instance.

        Every field, filter and ID-valued filter value in a list is looked up on this instance by name
        (see Get-JuribaListField, Get-JuribaListFilter and Get-JuribaListFilterOption) and the list's
        queryString is rewritten to use this instance's IDs. If anything a list uses cannot be found,
        for example a custom field, project, task, ring or bucket that does not exist here, the list is
        skipped and MissingReferences says what was missing. Lists that depend on a skipped list are
        skipped too. Nothing on this instance is created or changed apart from the lists themselves.

        A list whose name already exists here for the same object type is left alone and reported as
        Exists, unless -Overwrite is used, in which case its definition is replaced.

        New lists are owned by the user of the API key and are not shared. List sharing permissions are
        not imported.

        Use -WhatIf for a dry run: every list is resolved and reported, but nothing is created.

        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER InputObject
        The export object returned by Export-JuribaListDefinition, or the same object read back from JSON.

        .PARAMETER Path
        Path to a JSON file saved from Export-JuribaListDefinition.

        .PARAMETER Overwrite
        Replace the definition of lists that already exist with the same name and object type.

        .PARAMETER NameSuffix
        Optional. Text added to the end of every list name, for example " (imported)". The name with the
        suffix is used when checking whether a list already exists. Juriba DPC allows list names of up to
        50 characters, and longer names are skipped.

        .OUTPUTS
        One object per list with SourceListId, ListName, ObjectType, Status, TargetListId, MissingReferences,
        Reason and QueryString. Status is one of Created, CreatedBroken, Updated, Exists, Skipped, Failed or WhatIf.
        CreatedBroken means the list was created but DPC reports it as broken.

        .EXAMPLE
        PS> Import-JuribaListDefinition -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -Path ".\lists.json" -WhatIf

        .EXAMPLE
        PS> Import-JuribaListDefinition -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -Path ".\lists.json" | Select-Object SourceListId, ListName, Status, TargetListId, Reason | Export-Csv -Path ".\import-report.csv"
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = "InputObject")]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true, ParameterSetName = "InputObject", ValueFromPipeline = $true)]
        [object]$InputObject,
        [Parameter(Mandatory = $true, ParameterSetName = "Path")]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [switch]$Overwrite,
        [Parameter(Mandatory = $false)]
        [string]$NameSuffix
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

        if ($PSCmdlet.ParameterSetName -eq "Path") {
            try {
                $InputObject = Get-Content -Path $Path -Raw -ErrorAction Stop | ConvertFrom-Json
            }
            catch {
                Write-Error ("Failed to read '{0}': {1}" -f $Path, $_)
                return
            }
        }

        if (-not $InputObject.PSObject.Properties['schemaVersion'] -or $InputObject.schemaVersion -ne 1 -or -not $InputObject.PSObject.Properties['lists']) {
            Write-Error "The input is not a list export from Export-JuribaListDefinition (schemaVersion 1)."
            return
        }

        $connection = @{ Instance = $Instance; APIKey = $APIKey }
        $headers = @{'x-api-key' = $APIKey}
        $endpoints = @{ Device = "devices"; User = "users"; Application = "applications"; Mailbox = "mailboxes" }
        $lists = @($InputObject.lists)
        $types = @($lists | ForEach-Object { $_.objectType } | Select-Object -Unique)

        # Turns "Category|SubCategory|Path|Name" into something readable for the report.
        $describe = {
            param([string]$signature)
            (($signature -split '\|') | Where-Object { $_ }) -join ' > '
        }

        # Target metadata by signature, and existing lists by name.
        $fieldsBySig = @{}
        $filtersBySig = @{}
        $existing = @{}
        try {
            foreach ($type in $types) {
                Write-Verbose ("Getting {0} list fields and filters" -f $type)
                $f = @{}
                foreach ($field in @(Get-JuribaListField @connection -ObjectType $type -ErrorAction Stop)) {
                    if (-not $f.ContainsKey($field.Signature)) { $f[$field.Signature] = [System.Collections.Generic.List[object]]::new() }
                    $f[$field.Signature].Add($field)
                }
                $fieldsBySig[$type] = $f
                $f = @{}
                foreach ($filter in @(Get-JuribaListFilter @connection -ObjectType $type -ErrorAction Stop)) {
                    if (-not $f.ContainsKey($filter.Signature)) { $f[$filter.Signature] = [System.Collections.Generic.List[object]]::new() }
                    $f[$filter.Signature].Add($filter)
                }
                $filtersBySig[$type] = $f
                foreach ($list in @(Get-JuribaList @connection -ObjectType $type -ErrorAction Stop)) {
                    $existing[('{0}|{1}' -f $type, $list.listName.ToLowerInvariant())] = $list
                }
            }
        }
        catch {
            Write-Error $_
            return
        }

        $optionCache = @{}
        $savedListOptionUrls = [System.Collections.Generic.HashSet[string]]::new()
        $getOptions = {
            param($filter)
            if ($filter.IsSavedListFilter) { [void]$savedListOptionUrls.Add($filter.OptionsUrl) }
            if (-not $optionCache.ContainsKey($filter.OptionsUrl)) {
                $optionCache[$filter.OptionsUrl] = @(Get-JuribaListFilterOption @connection -OptionsUrl $filter.OptionsUrl -ErrorAction Stop)
            }
            $optionCache[$filter.OptionsUrl]
        }

        $userId = $null
        $results = @{}

        foreach ($list in $lists) {
            $targetName = '{0}{1}' -f $list.listName, $NameSuffix
            $result = [pscustomobject][ordered]@{
                SourceListId      = $list.sourceListId
                ListName          = $targetName
                ObjectType        = $list.objectType
                Status            = $null
                TargetListId      = $null
                MissingReferences = @()
                Reason            = $null
                QueryString       = $null
            }
            $results[[string]$list.sourceListId] = $result

            try {
                $existingKey = '{0}|{1}' -f $list.objectType, $targetName.ToLowerInvariant()
                $current = $existing[$existingKey]
                if ($current -and -not $Overwrite) {
                    $result.Status = 'Exists'
                    $result.TargetListId = $current.listId
                    $result.Reason = 'A list with this name already exists. Use -Overwrite to replace it.'
                    Write-Output $result
                    continue
                }

                if (-not $current -and $targetName.Length -gt 50) {
                    $result.Status = 'Skipped'
                    $result.Reason = 'The list name is {0} characters long. Juriba DPC allows up to 50. Use a shorter -NameSuffix or rename the source list.' -f $targetName.Length
                    Write-Output $result
                    continue
                }

                $notImported = @($list.dependsOn | Where-Object {
                    $dep = $results[[string]$_]
                    $dep -and $dep.Status -in @('Skipped', 'Failed')
                })
                if ($notImported.Count -gt 0) {
                    $names = ($notImported | ForEach-Object { "'{0}'" -f $results[[string]$_].ListName }) -join ', '
                    $result.Status = 'Skipped'
                    $result.Reason = 'Depends on {0}, which was not imported.' -f $names
                    Write-Output $result
                    continue
                }

                # Resolve every reference on this instance.
                $missing = [System.Collections.Generic.List[string]]::new()
                $columnMap = @{}
                $filterMap = @{}
                $valueMap = @{}
                $fieldIndex = $fieldsBySig[$list.objectType]
                $filterIndex = $filtersBySig[$list.objectType]

                foreach ($column in @($list.columns)) {
                    if (-not $column.signature) {
                        $missing.Add(("Column '{0}' (not found on the source instance)" -f $column.token))
                        continue
                    }
                    $found = $fieldIndex[$column.signature]
                    if (-not $found) {
                        $missing.Add(("Column '{0}'" -f (& $describe $column.signature)))
                    }
                    elseif ($found.Count -gt 1) {
                        $missing.Add(("Column '{0}' (more than one match)" -f (& $describe $column.signature)))
                    }
                    else {
                        $columnMap[$column.token] = $found[0].Token
                    }
                }

                foreach ($filter in @($list.filters)) {
                    if (-not $filter.signature) {
                        $missing.Add(("Filter '{0}' (not found on the source instance)" -f $filter.token))
                        continue
                    }
                    $found = $filterIndex[$filter.signature]
                    if (-not $found) {
                        $missing.Add(("Filter '{0}'" -f (& $describe $filter.signature)))
                        continue
                    }
                    if ($found.Count -gt 1) {
                        $missing.Add(("Filter '{0}' (more than one match)" -f (& $describe $filter.signature)))
                        continue
                    }
                    $target = $found[0]
                    $filterMap[$filter.token] = $target.Token

                    $values = @($filter.values)
                    if ($values.Count -eq 0) { continue }
                    $options = if ([string]$target.OptionsUrl -match '/filters/options/') { & $getOptions $target } else { @() }
                    $map = @{}
                    foreach ($value in $values) {
                        # A saved list that is part of this import maps straight to its new id.
                        if ($target.IsSavedListFilter -and $results.ContainsKey([string]$value.value)) {
                            $dep = $results[[string]$value.value]
                            if ($dep.TargetListId) {
                                $map[[string]$value.value] = [string]$dep.TargetListId
                                continue
                            }
                            if ($dep.Status -eq 'WhatIf') {
                                # Dry run: the list would have been created first.
                                continue
                            }
                        }
                        if (-not $value.path) {
                            $missing.Add(("Value '{0}' of filter '{1}' (not found on the source instance)" -f $value.value, (& $describe $filter.signature)))
                            continue
                        }
                        $match = @($options | Where-Object { $_.Path -eq $value.path })
                        if ($match.Count -eq 1) {
                            $map[[string]$value.value] = $match[0].Value
                        }
                        elseif ($match.Count -eq 0) {
                            $missing.Add(("Value '{0}' of filter '{1}'" -f $value.path, (& $describe $filter.signature)))
                        }
                        else {
                            $missing.Add(("Value '{0}' of filter '{1}' (more than one match)" -f $value.path, (& $describe $filter.signature)))
                        }
                    }
                    $valueMap[$filter.token] = $map
                }

                if ($missing.Count -gt 0) {
                    $result.Status = 'Skipped'
                    $result.MissingReferences = $missing.ToArray()
                    $result.Reason = 'Not everything this list uses exists on this instance.'
                    Write-Output $result
                    continue
                }

                # Rewrite the queryString with this instance's tokens and values.
                $parameters = @(ConvertFrom-JuribaListQueryString -QueryString ([string]$list.queryString))
                foreach ($p in $parameters) {
                    foreach ($segment in $p.Segments) {
                        switch ($segment.Kind) {
                            'Column' { if ($columnMap.ContainsKey($segment.Text)) { $segment.Text = $columnMap[$segment.Text] } }
                            'Filter' { if ($filterMap.ContainsKey($segment.Text)) { $segment.Text = $filterMap[$segment.Text] } }
                            'Value' {
                                if ($valueMap.ContainsKey($segment.Field) -and $valueMap[$segment.Field].ContainsKey($segment.Text)) {
                                    $segment.Text = $valueMap[$segment.Field][$segment.Text]
                                }
                            }
                        }
                    }
                }
                $queryString = ConvertTo-JuribaListQueryString -Parameters $parameters
                $result.QueryString = $queryString

                if ($current) {
                    if (-not $PSCmdlet.ShouldProcess($targetName, "Replace list definition")) {
                        $result.Status = 'WhatIf'
                        $result.TargetListId = $current.listId
                        Write-Output $result
                        continue
                    }
                    $uri = "{0}/apiv1/lists/{1}/{2}" -f $Instance, $endpoints[$list.objectType], $current.listId
                    $live = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
                    $body = [ordered]@{}
                    foreach ($field in @('listId', 'listName', 'listDescription', 'listType', 'userId', 'cachedKeySetId',
                                         'sharedReadAccessType', 'sharedEditAccessType', 'sharedAdministerAccessType')) {
                        if ($live.PSObject.Properties.Name -contains $field) { $body[$field] = $live.$field }
                    }
                    $body['queryString'] = $queryString
                    $json = $body | ConvertTo-Json
                    $null = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -ContentType "application/json" -Body ([System.Text.Encoding]::UTF8.GetBytes($json))
                    $result.Status = 'Updated'
                    $result.TargetListId = $current.listId
                }
                else {
                    if (-not $PSCmdlet.ShouldProcess($targetName, "Create list")) {
                        $result.Status = 'WhatIf'
                        Write-Output $result
                        continue
                    }
                    if (-not $userId) {
                        $userId = (Get-JuribaSessionUser @connection -ErrorAction Stop).userId
                    }
                    $created = New-JuribaList @connection -Name $targetName -UserId $userId -ListType $list.listType `
                        -QueryString $queryString -ObjectType $list.objectType -Confirm:$false -ErrorAction Stop
                    $result.TargetListId = $created.listId
                    $existing[$existingKey] = $created

                    # Ask DPC whether the new list is valid.
                    $result.Status = 'Created'
                    try {
                        $checkUri = "{0}/apiv1/lists/all/{1}/isListBrokenCommand?userAgnostic=true" -f $Instance, $created.listId
                        $null = Invoke-RestMethod -Uri $checkUri -Method PUT -Headers $headers -ContentType "application/json"
                    }
                    catch {
                        $result.Status = 'CreatedBroken'
                        $result.Reason = 'DPC reports the new list as broken: {0}' -f $_.Exception.Message
                    }
                }

                # New or changed lists can now be picked in saved-list filters.
                foreach ($url in $savedListOptionUrls) { $optionCache.Remove($url) }
            }
            catch {
                $result.Status = 'Failed'
                $result.Reason = $_.Exception.Message
                if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                    $result.Reason = '{0} {1}' -f $result.Reason, $_.ErrorDetails.Message
                }
            }
            Write-Output $result
        }
    }
}
