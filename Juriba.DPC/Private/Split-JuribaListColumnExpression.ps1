function Split-JuribaListColumnExpression {
    <#
        .SYNOPSIS
        Internal helper. Splits a decoded column parameter ($select, $orderby,
        $values, ...) into Column and Text segments.

        .DESCRIPTION
        Column parameters are comma-separated items. Each item is a field token,
        optionally followed by a space and a modifier, for example
        "hostname", "project_56_linkedApplicationReadiness asc" or "computerKey count".
        The token becomes a Column segment; separators and modifiers are Text.

        .PARAMETER Expression
        The decoded parameter value.

        .OUTPUTS
        An array of segment objects: Kind, Text.
    #>
    [CmdletBinding()]
    [OutputType([Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Expression
    )

    $segments = [System.Collections.Generic.List[object]]::new()
    $items = $Expression -split ','
    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($i -gt 0) {
            $segments.Add([pscustomobject]@{ Kind = 'Text'; Text = ',' })
        }
        $item = $items[$i]
        if ($item -match '^(\s*)([A-Za-z0-9_]+)(.*)$') {
            if ($Matches[1]) { $segments.Add([pscustomobject]@{ Kind = 'Text'; Text = $Matches[1] }) }
            $segments.Add([pscustomobject]@{ Kind = 'Column'; Text = $Matches[2] })
            if ($Matches[3]) { $segments.Add([pscustomobject]@{ Kind = 'Text'; Text = $Matches[3] }) }
        }
        elseif ($item) {
            $segments.Add([pscustomobject]@{ Kind = 'Text'; Text = $item })
        }
    }
    return , $segments.ToArray()
}
