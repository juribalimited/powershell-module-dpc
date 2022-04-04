Import-Module .\Juriba.Dashworks\Public\Get-DwCustomField.ps1 -Force

$params = @{
    Instance = "https://master.internal.juriba.com:8443"
    ApiKey = (Get-Secret DashworksApiKey -AsPlainText)
}


$result = Get-DwCustomField @params

($result | Where-Object {$_.name -eq "adsf"}).id