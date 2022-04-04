
$dwApiKey = Get-Secret DashworksApiKey -AsPlainText
$mecmCreds = Get-Secret MecmCredentials

$scriptparams = @{
    DwInstance = "https://master.internal.juriba.com:8443"
    DwAPIKey = $dwApiKey
    DwFeedName = "MECM Neil"
    MecmServerInstance = "dw-sccm12-dw1.dwlabs.local"
    MecmDatabaseName = "cm_dw1"
    MecmCredentials = $mecmCreds
}

# & '.\Juriba.Dashworks\Examples\MECM\MECM Device Import.ps1' @scriptparams


#& '.\Juriba.Dashworks\Examples\MECM\MECM Pkg Application Import.ps1' @scriptparams


& '.\Juriba.Dashworks\Examples\MECM\MECM Pkg Application to Device Import.ps1' @scriptparams
