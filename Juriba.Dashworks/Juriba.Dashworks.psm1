function Test-Dashworks {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    Write-Host "Hello $Name"
}
Export-ModuleMember -Function Test-Dashworks