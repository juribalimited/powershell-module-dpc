#requires -Version 7
function Get-JuribaTaskBulkUpdateLog {
    <#
        .SYNOPSIS
        Returns the log for a bulk task value update operation.

        .DESCRIPTION
        Returns the status and details of a bulk task value update operation
        using the Juriba DPC API v1 bulk update log endpoint.
        Use the opId returned by Set-JuribaTaskValueBulk to check the operation status.

        .PARAMETER Instance
        Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER OperationId
        The operation ID returned by Set-JuribaTaskValueBulk.

        .OUTPUTS
        The bulk update log object containing taskName, objectCount, outcome, submittedDate, startedDate, completedDate, error, and other details.

        .EXAMPLE
        PS> Get-JuribaTaskBulkUpdateLog -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -OperationId 2003

        .EXAMPLE
        PS> $result = Set-JuribaTaskValueBulk -ProjectId 49 -TaskId 100 -ObjectType Device -SelectValue 5 -Objects @(9141, 5123)
        PS> Get-JuribaTaskBulkUpdateLog -OperationId $result.opId
    #>

    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,

        [Parameter(Mandatory = $false)]
        [string]$APIKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$OperationId
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $uri = "{0}/apiv1/bulk-update/logs/{1}" -f $Instance, $OperationId
        $headers = @{
            'x-api-key' = $APIKey
        }

        try {
            $response = Invoke-WebRequest -Uri $uri -Headers $headers -Method GET
            $result = $response.Content | ConvertFrom-Json
            return $result
        }
        catch {
            Write-Error $_
        }
    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
