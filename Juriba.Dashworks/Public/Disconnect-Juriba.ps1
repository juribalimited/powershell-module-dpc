#requires -Version 7
function Disconnect-Juriba {
        <#
        .SYNOPSIS
        Removes and deletes connection object from session.

        .DESCRIPTION
        Removes and deletes connection object from session.

        .EXAMPLE

        PS> Disconnect-Juriba

    #>
    if (Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') {
        return "Removed API connection to {0}." -f $dwConnection.instance
        Remove-Variable 'dwConnection' -Scope 'Global'
    } else {
        Write-Error "No existing Juriba Connection found."
    }
}