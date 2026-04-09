#Requires -Version 7
function Wait-JuribaImportJob {
    <#
        .SYNOPSIS
        Polls an async import job until it completes or fails.

        .DESCRIPTION
        Takes a job URI returned by an async bulk import request and polls it until the job status
        is no longer InProgress. Returns the completed job details including per-item results.

        .PARAMETER Instance

        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey

        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER JobUri

        The job URI returned in the Location header of an async bulk import request.

        .PARAMETER PollIntervalMs

        Optional. Polling interval in milliseconds. Default is 500.

        .OUTPUTS
        Job details object containing requestId, status, error, and result properties.

        .EXAMPLE
        PS> $jobUri = New-JuribaImportDevice @DwParams -ImportId 1 -JsonBody $jsonBody -Async
        PS> $result = Wait-JuribaImportJob @DwParams -JobUri $jobUri

        .EXAMPLE
        PS> $jobUris = foreach ($batch in $batches) { New-JuribaImportDevice @DwParams -ImportId 1 -JsonBody $batch -Async }
        PS> $results = $jobUris | ForEach-Object { Wait-JuribaImportJob @DwParams -JobUri $_ }

    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [parameter(Mandatory=$true)]
        [string]$JobUri,
        [parameter(Mandatory=$false)]
        [int]$PollIntervalMs = 500
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $headers = @{'x-api-key' = $APIKey}

        try {
            $jobDetails = Invoke-RestMethod -Uri $JobUri -Method GET -Headers $headers
            while ($jobDetails.status -notin @("Completed", "Failed")) {
                Start-Sleep -Milliseconds $PollIntervalMs
                $jobDetails = Invoke-RestMethod -Uri $JobUri -Method GET -Headers $headers
            }
            if ($jobDetails.status -eq "Failed") {
                Write-Error ("Async job {0} failed: {1}" -f $jobDetails.requestId, $jobDetails.error)
            }
            return $jobDetails
        }
        catch {
            Write-Error $_
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
