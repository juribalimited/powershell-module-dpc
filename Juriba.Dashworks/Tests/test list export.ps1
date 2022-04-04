## CLEAN UP

#Uninstall-Module Juriba.Dashworks -Force

## TEST

#Install-Module Juriba.Dashworks 

#Get-Module -Name Juriba.Dashworks

$params = @{
    Instance = "https://master.internal.juriba.com:8443"
    APIKey = "bo0hv4+prmREW4S+O0DrLJVqm4OKO83ofgb7ysszfIpO20nI8KEzX7DrpnDZDXd605GurxmOnVa3oM2o+F9gqQ=="
    ListId = 18
    ObjectType = "Device"
}

$csvFileName = (".\Juriba.Dashworks\Tests\{0}-{1}.csv" -f $params.ListId, $params.ObjectType)

Export-DwList @params | Export-Csv -Path $csvFileName

Invoke-Item $csvFileName

