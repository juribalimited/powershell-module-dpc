Function Remove-JuribaCustomField {
    <#
    .SYNOPSIS

    Deletes a custom field.

    .DESCRIPTION

    Deletes a custom field using Dashworks API v1.

    .PARAMETER Instance

    Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

    .PARAMETER APIKey

    Optional. API key to be provided if not authenticating using Connect-Juriba.

    .PARAMETER CustomFieldId

    Id of the custom field to delete.

    .EXAMPLE

    PS> Remove-JuribaCustomField -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -CustomFieldId 42

    #>
    [alias("Remove-DwCustomField")]

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$CustomFieldId
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $uri = "{0}/apiv1/custom-fields/{1}" -f $Instance, $CustomFieldId
        $headers = @{'x-api-key' = $APIKey }
    
        if ($PSCmdlet.ShouldProcess($CustomFieldId)) {
            Invoke-WebRequest -Uri $uri -Method DELETE -Headers $headers -ContentType 'application/json'
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}