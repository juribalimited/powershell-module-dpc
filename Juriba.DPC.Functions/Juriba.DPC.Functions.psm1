# Requires -Version 7.1
Set-StrictMode -Version Latest

# Get public and private function definition files
$publicFunctions  = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -Exclude "*.Tests.*" -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -Exclude "*.Tests.*" -ErrorAction SilentlyContinue)

# Import all functions
foreach ($functionFile in @($publicFunctions + $privateFunctions)) {
    try {
        Write-Verbose "Importing $($functionFile.FullName)..."
        . $functionFile.FullName
    }
    catch {
        Write-Error "Failed to import function $($functionFile.FullName): $_"
    }
}

# Export public functions only
Export-ModuleMember -Function $publicFunctions.BaseName -Alias *