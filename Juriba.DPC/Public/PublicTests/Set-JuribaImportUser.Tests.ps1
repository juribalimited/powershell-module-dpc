# All Test files should import this
. ".\BaseTest.ps1"

Describe "Set-JuribaImportUser" {
    BeforeAll {
        Setup-TestEnvironment
        
    }
    Context "Acceptance test" {
    It "Get an automation back and verify not null" {
       try {

        $output = Get-JuribaAutomation -Instance $instance -APIKey $apiKey
        $output | Should Not Be $null
        }
        catch {
            Write-Error $_
            Break
        }
    }
    }
}