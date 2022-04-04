#test New Application

Import-Module .\Juriba.Dashworks\Public\New-DwImportApplication.ps1 -Force

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

#test Get Application Basic

Import-Module .\Juriba.Dashworks\Public\Get-DwImportApplication.ps1 -Force

$getAppParams = @{
    Instance = "https://master.internal.juriba.com:8443"
    ApiKey = (Get-Secret DashworksApiKey -AsPlainText)
    UniqueIdentifier = "LKJDLKSJLDJK"
    ImportId = 6
    InfoLevel = "Basic"
}

Get-DwImportApplication @getAppParams

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

#test Get Application All for feed

Import-Module .\Juriba.Dashworks\Public\Get-DwImportApplication.ps1 -Force

$getAppParams = @{
    Instance = "https://master.internal.juriba.com:8443"
    ApiKey = (Get-Secret DashworksApiKey -AsPlainText)
    ImportId = 6
    InfoLevel = "Basic"
}

$a = Get-DwImportApplication @getAppParams
$a.count

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