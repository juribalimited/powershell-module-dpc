# All Test files should import this
#Import-Module
Set-Location -Path $PSScriptRoot

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
