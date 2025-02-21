#requires -Version 7
function Get-JuribaDPCVersion {
    <#
    .SYNOPSIS
    Gets the current version of DPC with the provided instance. 

    .DESCRIPTION
    Returns the version or $true or $false if minimum version parameter is provided.

    .PARAMETER Instance

    DPC instance with specified port e.g. "https://myinstance.dashworks.app:8443

    .PARAMETER MinimumVersion

    Optional. Checks if version provided is greater than instance version. Returns true if greater, false otherwise

    .EXAMPLE

    PS> Get-JuribaDPCVersion -Instance "https://myinstance.dashworks.app:8443"
    PS> Get-JuribaDPCVersion -Instance "https://myinstance.dashworks.app:8443" -MinimumVersion "5.14"

#>
    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $True)]
        [string]$Instance,
        [Parameter(Mandatory = $False)]
        [string]$MinimumVersion
    )
    try {
        $versionUri = "{0}/apiv1/" -f $Instance
        $versionResult = Invoke-WebRequest -Uri $versionUri -Method GET -ErrorAction Stop
        # Regular expression to match the version pattern
        $regex = [regex]"\d+\.\d+\.\d+"
        # Extract the version
        [Version]$version = $regex.Match($versionResult).Value
        if ($MinimumVersion) {
            [version]$MinVersion = $MinimumVersion
            if ($version -ge $MinVersion) {
                return $true
            }
            else {
                return $false
            }
        }
        else {
            return $version
        }        
    }
    catch {
        throw $_
    }  
}