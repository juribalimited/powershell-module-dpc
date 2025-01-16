# All Test files should import this
#Import-Module 
. $PSScriptRoot\BaseTest.ps1

Describe "Get-JuribaAutomation" {
    #BeforeAll {
        #Setup-TestEnvironment
    #}
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
            $output.Count | Should -BeGreaterThan 1
        }
    }
}
