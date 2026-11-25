function Split-JuribaListFilterExpression {
    <#
        .SYNOPSIS
        Internal helper. Splits a decoded $filter expression into Text, Filter and
        Value segments.

        .DESCRIPTION
        Grammar (as stored by DPC):
            (field OPERATOR values [WHERE (codes)] AND field OPERATOR values ...) OR (...)

        OPERATOR is one or more upper-case words (EQUALS, NOT EQUALS, IS NOT EMPTY,
        ON AFTER RELATIVE, ...) or a symbol (>, >=, <, <=, =, <>).
        values is either a parenthesised list of quoted ('a','b') or bare (2_day_ago)
        items, possibly empty "()", or a single bare value (1, 2025-03-07).
        Quoted values escape a single quote by doubling it.

        Field tokens become Filter segments and each value becomes a Value segment
        whose Field property names the filter token it belongs to. Everything else,
        including operators, brackets, AND/OR and WHERE clauses, is Text, so joining
        every segment's Text rebuilds the input exactly.

        A purely numeric "field" (as in the always-false filter "(1=0)") is kept as
        Text because it is not a field reference.

        .PARAMETER Expression
        The decoded $filter value.

        .OUTPUTS
        An array of segment objects: Kind, Text and, for Value segments, Field and Quoted.
    #>
    [CmdletBinding()]
    [OutputType([Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Expression
    )

    $s = $Expression
    $n = $s.Length
    $i = 0
    $segments = [System.Collections.Generic.List[object]]::new()
    $text = [System.Text.StringBuilder]::new()

    $flush = {
        if ($text.Length -gt 0) {
            $segments.Add([pscustomobject]@{ Kind = 'Text'; Text = $text.ToString() })
            [void]$text.Clear()
        }
    }
    $isIdentChar = { param($c) [char]::IsLetterOrDigit($c) -or $c -eq '_' }
    # Reads a quoted value starting at $i (on the opening quote). Returns the
    # end index (exclusive) including the closing quote.
    $readQuoted = {
        param($start)
        $j = $start + 1
        while ($j -lt $n) {
            if ($s[$j] -eq "'") {
                if ($j + 1 -lt $n -and $s[$j + 1] -eq "'") { $j += 2; continue }
                return $j + 1
            }
            $j++
        }
        return $n
    }

    while ($i -lt $n) {
        $c = $s[$i]

        if ([char]::IsWhiteSpace($c) -or $c -eq '(' -or $c -eq ')') {
            [void]$text.Append($c); $i++; continue
        }

        if ($c -eq "'") {
            # A stray quoted string outside a condition; keep it intact.
            $end = & $readQuoted $i
            [void]$text.Append($s.Substring($i, $end - $i)); $i = $end; continue
        }

        if (-not (& $isIdentChar $c)) {
            [void]$text.Append($c); $i++; continue
        }

        # Read a word / identifier.
        $j = $i
        while ($j -lt $n -and (& $isIdentChar $s[$j])) { $j++ }
        $word = $s.Substring($i, $j - $i)

        if (($word -ceq 'AND' -or $word -ceq 'OR') -and ($j -ge $n -or [char]::IsWhiteSpace($s[$j]) -or $s[$j] -eq '(')) {
            [void]$text.Append($word); $i = $j; continue
        }

        # Start of a condition: $word is the field token.
        $field = $word
        if ($field -match '^\d+$') {
            [void]$text.Append($field)
        }
        else {
            & $flush
            $segments.Add([pscustomobject]@{ Kind = 'Filter'; Text = $field })
        }
        $i = $j

        # Operator: whitespace, then either a run of symbols or upper-case words.
        $k = $i
        while ($k -lt $n -and [char]::IsWhiteSpace($s[$k])) { $k++ }
        if ($k -lt $n -and '<>=!'.Contains($s[$k])) {
            while ($k -lt $n -and '<>=!'.Contains($s[$k])) { $k++ }
        }
        else {
            while ($true) {
                $m = $k
                while ($m -lt $n -and [char]::IsWhiteSpace($s[$m])) { $m++ }
                $w = $m
                while ($w -lt $n -and [char]::IsUpper($s[$w])) { $w++ }
                $isWord = ($w -gt $m) -and ($w -ge $n -or -not (& $isIdentChar $s[$w]))
                # AND/OR join conditions, so they end an operator that has no values, e.g. "IS EMPTY AND ...".
                if (-not $isWord -or $s.Substring($m, $w - $m) -cin @('AND', 'OR')) { break }
                $k = $w
            }
        }
        [void]$text.Append($s.Substring($i, $k - $i))
        $i = $k

        # Whitespace before the values.
        while ($i -lt $n -and [char]::IsWhiteSpace($s[$i])) { [void]$text.Append($s[$i]); $i++ }
        if ($i -ge $n) { break }

        if ($s[$i] -eq '(') {
            # Parenthesised value list.
            [void]$text.Append('('); $i++
            while ($i -lt $n -and $s[$i] -ne ')') {
                $ch = $s[$i]
                if ([char]::IsWhiteSpace($ch) -or $ch -eq ',') {
                    [void]$text.Append($ch); $i++; continue
                }
                if ($ch -eq "'") {
                    $end = & $readQuoted $i
                    & $flush
                    $raw = $s.Substring($i + 1, [Math]::Max(0, $end - $i - 2))
                    $segments.Add([pscustomobject]@{ Kind = 'Value'; Text = $raw.Replace("''", "'"); Field = $field; Quoted = $true })
                    $i = $end
                    continue
                }
                $e = $i
                while ($e -lt $n -and $s[$e] -ne ',' -and $s[$e] -ne ')') { $e++ }
                $bare = $s.Substring($i, $e - $i).TrimEnd()
                & $flush
                $segments.Add([pscustomobject]@{ Kind = 'Value'; Text = $bare; Field = $field; Quoted = $false })
                $trailing = $s.Substring($i + $bare.Length, $e - $i - $bare.Length)
                if ($trailing) { [void]$text.Append($trailing) }
                $i = $e
            }
            if ($i -lt $n) { [void]$text.Append(')'); $i++ }
        }
        elseif ($s[$i] -ne ')' -and $s.Substring($i) -cnotmatch '^(AND|OR)(?=[\s(])') {
            # Single bare value, e.g. ">= 1" or "> 2025-03-07".
            $e = $i
            while ($e -lt $n -and -not [char]::IsWhiteSpace($s[$e]) -and $s[$e] -ne ')') { $e++ }
            & $flush
            $segments.Add([pscustomobject]@{ Kind = 'Value'; Text = $s.Substring($i, $e - $i); Field = $field; Quoted = $false })
            $i = $e
        }

        # Optional association WHERE clause: kept as text.
        if ($s.Substring($i) -match '^(\s+WHERE\s*\([^)]*\))') {
            [void]$text.Append($Matches[1])
            $i += $Matches[1].Length
        }
    }

    & $flush
    return , $segments.ToArray()
}
