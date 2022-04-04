
function Get-CFW11CPUSupported {
    param (
        [PSCustomObject]$body
    )
    if (-not $global:lookupTable) {
        $global:lookupTable = Import-Csv -Path .\Juriba.Dashworks\Examples\Reference\Lkp-CPU-W11-Support.csv -Encoding utf8 
    }

    $cfName = "W11 CPU Supported"

    if (-not $global:cfId) {
        $global:cfId = (Get-DwCustomField @dwParams | Where-Object {$_.name -eq $cfName}).id
        if (-not $global:cfId) {
            New-DwCustomField @dwParams -name $cfName -CSVColumnHeader $($cfName.Replace(" ", "")) -Type Text -ObjectTypes Device -IsActive 1 -AllowUpdate ETL
            $global:cfId = (Get-DwCustomField @dwParams | Where-Object {$_.name -eq $cfName}).id
        }
    }
    
    $manufacturer = $body.processorManufacturer
    $model = $body.processorModel

    if ((($lookupTable | Where-Object { $_.Manufacturer -eq $manufacturer -And $model -match $_.Model }).count) -gt 0) {
        $value = "Compatible"
    }
    else {
        $value = "Not Compatible"
    }

    $cfv = @{"id" = $global:cfId; "value" = $value}

    return $cfv
}


$dwParams = @{
    Instance = "https://mstesting.dashworks.juriba.app"
    ApiKey = "r2rfDy+rIna1VPGBxqBvu959Z3zY+JEluoULD8xFTOgkxswIryeda00v5A237eLYnJXzsfyo/8kD5cHfBtFliA=="
}

$importId = 1

Import-Module .\Juriba.Dashworks\Public\Get-DwCustomField.ps1 -Force
Import-Module .\Juriba.Dashworks\Public\Get-DwImportDevice.ps1 -Force

$devices = @(Get-DwImportDevice @dwParams -ImportId $importId -InfoLevel Full)

foreach ($device in $devices) {
    $cfv = Get-CFW11CPUSupported($device)
    #$postJson = @{uniqueIdentifier = $device.uniqueIdentifier; customFieldValues = @($cfv)} | ConvertTo-Json 
    
    $postJson = @{customFieldValues = @($cfv)} | ConvertTo-Json 
    #$postJson
    $device.hostname

    Set-DwImportDevice @dwParams -UniqueIdentifier $device.uniqueIdentifier -ImportId $importId -JsonBody $postJson

}
