# All Test files should import this
#Import-Module
Set-Location -Path $PSScriptRoot

. $PSScriptRoot\BaseTest.ps1

Describe "Get-JuribaAutomation" { 
    Context "Acceptance test" {
        # Show the current directory
        Write-Host "Current directory: $(Get-Location)"

        # List all files in the current directory for debugging
        Write-Host "Files in current directory:"
        Get-ChildItem -Path (Get-Location)

        # Attempt to dot-source BaseTest.ps1
        $baseTestPath = "$PSScriptRoot\BaseTest.ps1"

        Write-Host "Attempting to dot-source: $baseTestPath"

        if (Test-Path $baseTestPath) {
            Write-Host "BaseTest.ps1 found. Dot-sourcing the file..."
            . $baseTestPath  # Dot-source the BaseTest.ps1 script
        } else {
            Write-Host "BaseTest.ps1 NOT found at: $baseTestPath"
        }
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
