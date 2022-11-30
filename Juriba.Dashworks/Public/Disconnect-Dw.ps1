#requires -Version 7
function Disconnect-Dw {
        <#
        .SYNOPSIS
        Removes and deletes connection object from session.

        .DESCRIPTION
        Removes and deletes connection object from session.

        .EXAMPLE

        PS> Disconnect-Dw

    #>
    if (Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') {
        return "Removed API connection to {0}." -f $dwConnection.instance
        Remove-Variable 'dwConnection' -Scope 'Global'
    } else {
        Write-Error "No existing dwConnection found."
    }
}