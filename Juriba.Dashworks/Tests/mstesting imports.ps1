# $params = @{
#     DwInstance = "https://mstesting.dashworks.juriba.app" #didn't work with port :8443 
#     DwAPIKey = "r2rfDy+rIna1VPGBxqBvu959Z3zY+JEluoULD8xFTOgkxswIryeda00v5A237eLYnJXzsfyo/8kD5cHfBtFliA==" ##needs more security to use properly
#     DwFeedName = "SCCMFeedMEW11ASS"
#     MecmServerInstance = "DW-W11AS-ME.dwlabs.local"
#     MecmDatabaseName = "SCCM"
#     MecmCredentials = "dashworksadmin"
# }

#  & '.\Juriba.Dashworks\Examples\MECM\MECM Device Import mstest.ps1' @params

#  $params = @{
#     DwInstance = "https://mstesting.dashworks.juriba.app" #didn't work with port :8443 
#     DwAPIKey = "r2rfDy+rIna1VPGBxqBvu959Z3zY+JEluoULD8xFTOgkxswIryeda00v5A237eLYnJXzsfyo/8kD5cHfBtFliA==" ##needs more security to use properly
#     DwFeedName = "SCCMFeedMEW11ASS"
#     MecmServerInstance = "DW-W11AS-ME.dwlabs.local"
#     MecmDatabaseName = "SCCM"
#     MecmCredentials = "dashworksadmin"
# }

#  & '.\Juriba.Dashworks\Examples\MECM\MECM Device Import Parallel.ps1' @params


 $params = @{
    Instance = "https://mstesting.dashworks.juriba.app" #didn't work with port :8443 
    APIKey = "r2rfDy+rIna1VPGBxqBvu959Z3zY+JEluoULD8xFTOgkxswIryeda00v5A237eLYnJXzsfyo/8kD5cHfBtFliA==" ##needs more security to use properly
    
}
Import-Module .\Juriba.Dashworks\Public\Get-DwImportDevice.ps1 -Force

$result = Get-DwImportDevice @params -ImportId 1 -UniqueIdentifier "100174" -InfoLevel Full 

