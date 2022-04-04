#test Get Device Feed

Import-Module .\Juriba.Dashworks\Public\Get-DwImportDeviceFeed.ps1 -Force

$getDeviceFeedParams = @{
    Instance = "https://master.internal.juriba.com:8443"
    ApiKey = (Get-Secret DashworksApiKey -AsPlainText)
    ImportId = 6
}

Get-DwImportDeviceFeed @getDeviceFeedParams

#test Get Device Feed by Name

Import-Module .\Juriba.Dashworks\Public\Get-DwImportDeviceFeed.ps1 -Force

$getDeviceFeedParams = @{
    Instance = "https://master.internal.juriba.com:8443"
    ApiKey = (Get-Secret DashworksApiKey -AsPlainText)
    Name = "FR"
}

Get-DwImportDeviceFeed @getDeviceFeedParams

#test New Device

Import-Module .\Juriba.Dashworks\Public\New-DwImportDevice.ps1 -Force

$jsonBody = @{
    uniqueIdentifier = "LKJDLKSJLDJK"
    manufacturer = "Microsoft"
    name = "Windows"
    version = "10.0"
    owner = "/imports/users/14/items/ACP1246091"
}

$newAppParams = @{
    Instance = "https://master.internal.juriba.com:8443"
    ApiKey = (Get-Secret DashworksApiKey -AsPlainText)
    ImportId = 6
    JsonBody = ($jsonBody | ConvertTo-Json)
}

New-DwImportApplication @newAppParams

#test Get Device by UniqueIdentifier

Import-Module .\Juriba.Dashworks\Public\Get-DwImportDevice.ps1 -Force

$getDeviceParams = @{
    Instance = "https://rhea.internal.juriba.com:8443"
    ApiKey = (Get-Secret DashworksRheaApiKey -AsPlainText)
    #UniqueIdentifier = "00BDM1JUR8IF419"
    #Hostname = "DW-DASHWORKS"
    Filter = "eq(SerialNumber, '60861')"
    ImportId = 6
    InfoLevel = "Full"
    #Limit = 100
}

$d = Get-DwImportDevice @getDeviceParams
$d.count

#test Get Application Full

Import-Module .\Juriba.Dashworks\Public\Get-DwImportApplication.ps1 -Force

$getAppParams = @{
    Instance = "https://master.internal.juriba.com:8443"
    ApiKey = (Get-Secret DashworksApiKey -AsPlainText)
    UniqueIdentifier = "LKJDLKSJLDJK"
    ImportId = 6
    InfoLevel = "Full"
}

Get-DwImportApplication @getAppParams

#test set application

Import-Module .\Juriba.Dashworks\Public\Set-DwImportApplication.ps1 -Force

$jsonBody = @{
    manufacturer = "SoftMicro"
    name = "Doors"
    version = "90.0"
}

$setAppParams = @{
    Instance = "https://master.internal.juriba.com:8443"
    ApiKey = (Get-Secret DashworksApiKey -AsPlainText)
    ImportId = 6
    JsonBody = ($jsonBody | ConvertTo-Json)
    UniqueIdentifier = "LKJDLKSJLDJK"
}

Set-DwImportApplication @setAppParams

#test remove application

Import-Module .\Juriba.Dashworks\Public\Remove-DwImportApplication.ps1 -Force

$removeAppParams = @{
    Instance = "https://master.internal.juriba.com:8443"
    ApiKey = (Get-Secret DashworksApiKey -AsPlainText)
    ImportId = 6
    UniqueIdentifier = "LKJDLKSJLDJK"
}

Remove-DwImportApplication @removeAppParams