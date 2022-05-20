Function Remove-DwCustomField {
    <#
    .SYNOPSIS

    Deletes a custom field.

    .DESCRIPTION

    Deletes a custom field using Dashworks API v1.

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Instance,
        [Parameter(Mandatory = $true)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$CustomFieldId
    )

    $uri = "{0}/apiv1/custom-fields/{1}" -f $Instance, $CustomFieldId
    $headers = @{'x-api-key' = $APIKey }

    if ($PSCmdlet.ShouldProcess($CustomFieldId)) {
        Invoke-WebRequest -Uri $uri -Method DELETE -Headers $headers -ContentType 'application/json'
    }
}