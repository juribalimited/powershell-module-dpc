<#
This is the base test file that each Pester test should import
Contains all common testing infrastructure
#>
. "$PSScriptRoot\TestingVariables.ps1"

function GetFunctionFile {
   # Needed to make sure the directory paths are correct
   Set-Location -Path $PSScriptRoot
   
   # Access the caller's invocation and get its script path
   $callerInvocation = $MyInvocation
   while ($callerInvocation.InvocationName -eq "MyFunction") {
       $callerInvocation = $callerInvocation.MyInvocation
   }
   
   # Extract the file name from the full path
   $callerScriptName = [System.IO.Path]::GetFileName($callerInvocation.ScriptName)

    # Get the directory of the current script
    $currentScriptDir = Split-Path $PSCommandPath -Parent

    # Get the path one directory up
    $parentDir = Split-Path $currentScriptDir -Parent

    # Replace '.Tests.ps1' with '.ps1' and make full path
    $scriptToRun = Join-Path -Path $parentDir $callerScriptName.Replace('.Tests.ps1', '.ps1')

    # Dot-source
    . $scriptToRun
}

function SetUp-TestEnvironment{
    #GetFunctionFile
}

function Cleanup-TestEnvironment{
}