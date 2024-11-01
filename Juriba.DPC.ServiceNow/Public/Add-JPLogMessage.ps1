function Add-JPLogMessage {
    [OutputType([string])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,
        [Parameter(Mandatory=$True)]
        [string]$APIKey,
        [parameter(Mandatory=$True)]
        [ValidateSet('Noise','Debug','Info','Warning','Error','Fatal')]
        [string]$Priority,
        [Parameter(Mandatory=$True)]
        [string]$Message
    )
    $Headers = @{"accept" = "application/json";"X-API-KEY" = $APIKey;"Content-Type"="application/json"}
    $body = @{"message"=$Message;"source"="Import Script";"level"=$Priority} | ConvertTo-Json
    Invoke-webrequest -uri "$($Instance)/apiv2/event-logs" -Method Post -Headers $Headers -Body $Body -AllowInsecureRedirect | Out-Null
}