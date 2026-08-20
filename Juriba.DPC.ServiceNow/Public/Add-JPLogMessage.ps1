function Add-JPLogMessage {
    <#
    .Synopsis
    Writes a message to the active Juriba DPC event log.

    .Description
    Posts a log message to the Juriba DPC apiv2 event-logs endpoint. Use Start-JPLog to begin an event log
    before writing messages and Close-JPLog to stop it.

    .Parameter Instance
    The URI to the Juriba DPC instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Parameter Priority
    The log level of the message. One of: Noise, Debug, Info, Warning, Error, Fatal.

    .Parameter Message
    The message text to write to the event log.

    .Example
    Add-JPLogMessage -Instance $Instance -APIKey $APIKey -Priority Info -Message "ServiceNow sync started"
    #>
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
