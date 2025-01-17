# All Test files should import this
#Import-Module
Set-Location -Path $PSScriptRoot
Write-Host "PSScriptRoot: $PSScriptRoot"
Write-Host "Attempting to dot-source BaseTest.ps1"
#
if (Test-Path "$PSScriptRoot\BaseTest.ps1") {
    Write-Host "Dot-sourcing BaseTest.ps1"
    . $PSScriptRoot\BaseTest.ps1
} else {
    Write-Host "BaseTest.ps1 not found at $PSScriptRoot\BaseTest.ps1"
}

. $PSScriptRoot\BaseTest.ps1

Describe "Get-JuribaAutomation" {
 
    Context "Acceptance test" {
       GetFunctionFile

       try {

        $output = Get-JuribaAutomation -Instance $instance -APIKey $apiKey
        }
        catch {
            Write-Error $_
            
        }

        It "Get an automation back and verify not null" {
            $output | Should -Not -BeNullOrEmpty
        }

        It 'The count is greater than 1' {
            $output.Length | Should -BeGreaterThan 1
        }
    }
}
