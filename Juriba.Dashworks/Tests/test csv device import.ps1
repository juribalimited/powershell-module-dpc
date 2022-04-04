$dwApiKey = Get-Secret DashworksApiKey -AsPlainText
$path = "C:\Users\neilw\OneDrive - Juriba\Documents\faker\devies 100000.csv"

$scriptparams = @{
    DwInstance = "https://master.internal.juriba.com:8443"
    DwAPIKey = $dwApiKey
    DwFeedName = "CSV 1000"
    Path = $path
}

$stopWatch = New-Object System.Diagnostics.Stopwatch
$stopWatch.Start()

#& '.\Juriba.Dashworks\Examples\CSV\CSV Device Import.ps1' @scriptparams
& '.\Juriba.Dashworks\Examples\CSV\CSV Device Import Parallel.ps1' @scriptparams

$stopWatch.Stop()
$stopWatch.Elapsed.TotalSeconds
