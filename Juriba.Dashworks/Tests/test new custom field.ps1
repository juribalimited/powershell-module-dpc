Import-Module .\Juriba.Dashworks\Public\New-DwCustomField.ps1 -Force


# $params = @{
#     Instance = "https://master.internal.juriba.com:8443"
#     ApiKey = (Get-Secret DashworksApiKey -AsPlainText)
#     Name = "Test CF"
#     CSVColumnHeader = "TestCF"
#     Type = "Text"
#     ObjectTypes = "Device"
#     IsActive = $true
# }

# $result = New-DwCustomField @params 


$params = @{
    Instance = "https://master.internal.juriba.com:8443"
    ApiKey = (Get-Secret DashworksApiKey -AsPlainText)
    Name = "Test CF ETL"
    CSVColumnHeader = "TestCFETL"
    Type = "Text"
    ObjectTypes = "Device"
    IsActive = $true
    AllowUpdate = "ETL"
}

$result = New-DwCustomField @params 