function ConvertTo-JuribaListQueryString {
    <#
        .SYNOPSIS
        Internal helper. Rebuilds a list queryString from the parameter objects
        produced by ConvertFrom-JuribaListQueryString.

        .DESCRIPTION
        Joins each parameter's segments back into a value. Quoted filter values are
        re-quoted, doubling any single quote. Parameters that were percent-encoded in
        the source are re-encoded the way the DPC UI does it (encodeURIComponent:
        everything except A-Z a-z 0-9 - _ . ! ~ * ' ( ) is percent-encoded as UTF-8);
        the others are written literally.

        .PARAMETER Parameters
        The parameter objects from ConvertFrom-JuribaListQueryString, optionally with
        modified segment Text.

        .OUTPUTS
        The queryString.
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Parameters
    )

    $parts = foreach ($p in $Parameters) {
        if (-not $p.HasValue) {
            $p.Name
            continue
        }
        $value = -join ($p.Segments | ForEach-Object {
            if ($_.Kind -eq 'Value' -and $_.Quoted) { "'" + $_.Text.Replace("'", "''") + "'" } else { $_.Text }
        })
        if ($p.Encoded) {
            $sb = [System.Text.StringBuilder]::new()
            foreach ($b in [System.Text.Encoding]::UTF8.GetBytes($value)) {
                $ch = [char]$b
                if (($b -lt 128) -and ([char]::IsLetterOrDigit($ch) -or "-_.!~*'()".Contains($ch))) {
                    [void]$sb.Append($ch)
                }
                else {
                    [void]$sb.AppendFormat('%{0:X2}', $b)
                }
            }
            $value = $sb.ToString()
        }
        '{0}={1}' -f $p.Name, $value
    }
    return ($parts -join '&')
}
