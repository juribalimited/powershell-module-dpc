function ConvertFrom-JuribaListQueryString {
    <#
        .SYNOPSIS
        Internal helper. Parses a list queryString into segments so that field
        tokens and filter values can be found and rewritten.

        .DESCRIPTION
        A list queryString is a set of $-parameters joined by '&', for example
        "$filter=(project_130_ringId%20EQUALS%20('235'))&$select=hostname,project_130_ring".

        Each parameter is URL-decoded and split into segments:
          - Text    : anything that is passed through unchanged.
          - Column  : a field token in $select, $pinleft, $pinright, $orderby,
                      $rowgroups, $columns or $values.
          - Filter  : a field token at the start of a $filter condition.
          - Value   : one value of a $filter condition. Field holds the filter
                      token it belongs to and Quoted says whether it was quoted.

        Joining every segment's Text gives back the decoded parameter, and
        ConvertTo-JuribaListQueryString re-encodes it. Parameters that were
        percent-encoded in the source are re-encoded and the others are left
        literal, because DPC stores $filter encoded and the other parameters
        with literal commas. An unmodified parse therefore rebuilds the exact
        original string.

        The filter grammar is: (field OPERATOR values [WHERE (codes)] AND ...) OR (...)
        where values is a parenthesised list of quoted or bare values, or a single
        bare value (e.g. ">= 1", "> 2025-03-07"). WHERE codes are fixed association
        codes and are kept as text.

        .PARAMETER QueryString
        The queryString as stored on the list (URL-encoded).

        .OUTPUTS
        An array of parameter objects: Name, Encoded, Segments.
    #>
    [CmdletBinding()]
    [OutputType([Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$QueryString
    )

    $columnParams = @('$select', '$pinleft', '$pinright', '$orderby', '$rowgroups', '$columns', '$values')
    $parameters = [System.Collections.Generic.List[object]]::new()

    if ([string]::IsNullOrEmpty($QueryString)) {
        return $parameters.ToArray()
    }

    foreach ($part in $QueryString -split '&') {
        $kv = $part -split '=', 2
        if ($kv.Count -lt 2) {
            # Not a name=value pair; keep it verbatim.
            $parameters.Add([pscustomobject]@{
                Name     = $part
                HasValue = $false
                Encoded  = $false
                Segments = @()
            })
            continue
        }

        $name = $kv[0]
        $rawValue = $kv[1]
        $encoded = $rawValue.Contains('%')
        $value = if ($encoded) { [System.Uri]::UnescapeDataString($rawValue) } else { $rawValue }

        $segments = if ($name -eq '$filter') {
            Split-JuribaListFilterExpression -Expression $value
        }
        elseif ($columnParams -contains $name) {
            Split-JuribaListColumnExpression -Expression $value
        }
        else {
            @([pscustomobject]@{ Kind = 'Text'; Text = $value })
        }

        $parameters.Add([pscustomobject]@{
            Name     = $name
            HasValue = $true
            Encoded  = $encoded
            Segments = @($segments)
        })
    }

    return $parameters.ToArray()
}
