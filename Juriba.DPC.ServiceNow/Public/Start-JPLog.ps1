function Start-JPLog {
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