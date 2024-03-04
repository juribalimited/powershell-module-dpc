

$ETLName = "Juriba ETL (Transform Only)"
# Define $JuribaParams globally
$global:JuribaParams = @{
    Instance = $JuribaApiEndpoint
    APIKey = $JuribaAPIKey
}

##  DataCheckCompleted needs to be defined by the logging process
if ($DataCheckComplete) {
    #Trigger ETL
    $uri = "{0}/apiv2/etl-jobs" -f $JuribaParams.Instance
    $ETLJobs = Invoke-RestMethod -Headers $JPHeaders -Uri $uri -Method Get -AllowInsecureRedirect
    $ETLID = ($ETLJobs | where-object {$_.name -eq $ETLName}).id
    $uri = "{0}/apiv2/etl-jobs/{1}" -f $DWParams.Instance,$ETLID
    Invoke-RestMethod -Headers $JPHeaders -Uri $uri -Method Post -AllowInsecureRedirect # | out-null
 
    $currentUTCtime = (Get-Date).ToUniversalTime()
    # Write an information log with the current time.
    Add-LogEntry -Entry "ETL Triggered." WriteToJUriba $true
} else {
    Add-LogEntry -Priority Error -Message "Data Check Failed. ETL not launched."  WriteToJUriba $true
}