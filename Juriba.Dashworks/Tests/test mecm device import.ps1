## CLEAN UP

##Uninstall-Module Juriba.Dashworks -Force

## TEST

##Install-Module Juriba.Dashworks 

##Get-Module -Name Juriba.Dashworks

$params = @{
    DwInstance = "https://master.internal.juriba.com:8443"
    DwAPIKey = "bo0hv4+prmREW4S+O0DrLJVqm4OKO83ofgb7ysszfIpO20nI8KEzX7DrpnDZDXd605GurxmOnVa3oM2o+F9gqQ=="
    DwFeedName = "Neil Test2"
    MecmServerInstance = "dw-sccm12-dw1.dwlabs.local"
    MecmDatabaseName = "cm_dw1"
}

& '.\Juriba.Dashworks\Examples\MECM\MECM Device Import.ps1' @params

