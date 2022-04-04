
$dwApiKey = Get-Secret DashworksApiKey -AsPlainText
$mecmCreds = Get-Secret MecmCredentials

$scriptparams = @{
    DwInstance = "https://master.internal.juriba.com:8443"
    DwAPIKey = $dwApiKey
    DwFeedName = "MECM Neil Apps"
    MecmServerInstance = "dw-sccm12-dw1.dwlabs.local"
    MecmDatabaseName = "cm_dw1"
    MecmCredentials = $mecmCreds
}

#& '.\Juriba.Dashworks\Examples\MECM\MECM Device Import.ps1' @scriptparams

# & '.\Juriba.Dashworks\Examples\MECM\MECM App Application Import.ps1' @scriptparams

& '.\Juriba.Dashworks\Examples\MECM\MECM App Application to Device Import.ps1' @scriptparams
