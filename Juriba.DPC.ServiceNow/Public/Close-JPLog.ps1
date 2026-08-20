function Close-JPLog {
    <#
    .Synopsis
    Stops the active Juriba DPC event log.

    .Description
    Posts to the Juriba DPC apiv2 stop-event-logging-command endpoint to close the event log started
    with Start-JPLog.

    .Parameter Instance
    The URI to the Juriba DPC instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Example
    Close-JPLog -Instance $Instance -APIKey $APIKey
    #>
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,

        [Parameter(Mandatory=$True)]
        [string]$APIKey
    )
    $Headers = @{"accept" = "application/json";"X-API-KEY" = $APIKey;"Content-Type"="application/json"}
    Invoke-webrequest -uri "$($Instance)/apiv2/event-logs/stop-event-logging-command" -Method Post -Headers $Headers -AllowInsecureRedirect | Out-Null
}
