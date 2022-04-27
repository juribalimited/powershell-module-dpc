Function Remove-DwTag {
    <#
    .SYNOPSIS

    Deletes a list tag.

    .DESCRIPTION

    Deletes a list tag using Dashworks API v1.

    .EXAMPLE

    PS> Remove-DwTag-Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -Tag 123 -Confirm:$false

    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Instance,
        [Parameter(Mandatory = $true)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [string]$Tag
    )

    $body = @{
        tag = $Tag
    } | ConvertTo-Json

    $uri = "{0}/apiv1/tags" -f $Instance
    $headers = @{ 'x-api-key' = $APIKey }

    try {
        if ($PSCmdlet.ShouldProcess(
            ("Removing Tag {0}" -f $Tag),
            ("This action will delete Tag {0} from all lists, continue?" -f $Tag),
            "Confirm Tag deletion"
            )
        ) {
            Invoke-WebRequest -Uri $uri -Method DELETE -Headers $headers -Body $body -ContentType 'application/json'
        }
    }
    catch {
            Write-Error $_
    }
}