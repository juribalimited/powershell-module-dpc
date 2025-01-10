. ".\TestVariables.ps1"

BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1','.ps1').Replace('\Tests\','\Public\')
}

Describe 'Get-JuribaImportDevice' {
    Context 'Given API key "$apiKey" and non empty Import ID "$importId"' {
        $expectedProperties = @("uniqueIdentifier", "hostname", "site", "computerDomain", "operatingSystemName", "operatingSystemVersion", "operatingSystemArchitecture", "operatingSystemServicePack", "computerManufacturer", "computerModel", "chassisType", "virtualMachine", "purchaseDate", "firstSeenDate", "lastSeenDate", "buildDate", "bootupDate", "serialNumber", "processorCount", "processorManufacturer", "processorModel", "processorSpeed", "processor64Bit", "memoryKb", "networkCardDescription", "iPv4Address", "iPv4SubnetMask", "iPv6Address", "iPv6SubnetMask", "macAddress", "videoCardCount", "videoCardManufacturer", "videoCardModel", "soundCardCount", "soundCardManufacturer", "soundCardModel", "hddCount", "totalHDDSpaceMb", "targetDriveFreeSpaceMb", "biosManufacturer", "biosName", "biosVersion", "monitorCount", "monitorManufacturer", "monitorModel", "monitorScreenHeight", "monitorScreenWidth", "warrantyDate", "memoryMB", "secureBootEnabled", "tpmEnabled", "tpmVersion", "isVirtualizationCapable", "windowsBranch", "servicingState", "virtualMachineHost", "poNumber", "orderNumber", "orderStatus", "orderStatusDate", "estimatedShippingDate", "deliveredDate", "assetTag", "leaseStart", "leaseEnd", "leaseCompany", "ownership", "lastUpdated", "chassisTypeId", "windowsBranchId", "servicingStateId", "owner", "customFieldValues", "applications", "properties")
        try {
            $output = Get-JuribaImportDevice -Instance $instance -APIKey $apiKey -ImportId $importId -InfoLevel Full -ErrorAction Stop
        } catch {
            Write-Error $_
            Break
        }
        if ($output.Count -ge 1) {
            $counter = 0
            #Takes first output object and validates all expected properties exist
            $responseProperties = $output[0].psobject.Properties.Name
            foreach ($property in $expectedProperties) {
                if ($responseProperties -contains $property) {
                    $counter++
                }
            }
        }
        It 'Returns non empty list of device objects' {
            $output.Count | Should -Not -BeNullOrEmpty
        }
        It 'Returns objects with all expected properties' {
            $responseProperties.Count | Should -BeExactly $expectedProperties.Count
        }
    }
}

Describe 'Set-JuribaImportDevice' {
    Context 'Given API key "$apiKey" and non empty Import ID "$importId"' {
        try {
            $output = Set-JuribaImportDevice -Instance $instance -APIKey $apiKey -ImportId $importId -InfoLevel Full -ErrorAction Stop
        } catch {
            Write-Error $_
            Break
        }
        if ($output.Count -ge 1) {
            $counter = 0
            #Takes first output object and validates all expected properties exist
            $responseProperties = $output[0].psobject.Properties.Name
            foreach ($property in $expectedProperties) {
                if ($responseProperties -contains $property) {
                    $counter++
                }
            }
        }
        It 'Returns non empty list of device objects' {
            $output.Count | Should -Not -BeNullOrEmpty
        }
        It 'Returns objects with all expected properties' {
            $responseProperties.Count | Should -BeExactly $expectedProperties.Count
        }
    }
}