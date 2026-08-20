function Start-JPLog {
    <#
    .Synopsis
    Starts a Juriba DPC event log.

    .Description
    Posts to the Juriba DPC apiv2 start-event-logging-command endpoint to begin an event log that
    Add-JPLogMessage writes to. Close the log with Close-JPLog when the run completes.

    .Parameter Instance
    The URI to the Juriba DPC instance being examined.

    .Parameter APIKey
    The APIKey for a user with access to the required resources.

    .Example
    Start-JPLog -Instance $Instance -APIKey $APIKey
    #>
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$True)]
        [string]$Instance,

        [Parameter(Mandatory=$True)]
        [string]$APIKey
    )
    $Headers = @{"accept" = "application/json";"X-API-KEY" = $APIKey;"Content-Type"="application/json"}
    if ($PSCmdlet.ShouldProcess(
                ("Starting logging"),
                ("This start a Juriba DPC Event Log, continue?"),
                "Confirm Event Log Creation"
                )
    ) {
        Invoke-webrequest -uri "$($Instance)/apiv2/event-logs/start-event-logging-command" -Method Post -Headers $Headers -Body "{""ServiceId"": 19}" -AllowInsecureRedirect | Out-Null
    }
}
