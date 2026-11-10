function Get-JuribaCustomField {
    <#
    .SYNOPSIS

    Gets custom fields.

    .DESCRIPTION

    Gets custom fields using the Dashworks API v1.

    .PARAMETER Instance

    Optional. Juriba instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dpc.juriba.app

    .PARAMETER APIKey

    Optional. API key to be provided if not authenticating using Connect-Juriba.

    .PARAMETER CustomFieldId

    Optional. Id of a single custom field to return. When supplied, the full definition of that field is returned,
    including allowExternalUpdate, valueTypeId and updateSourceId, which are not included when listing all custom fields.

    .OUTPUTS

    All custom fields, or a single custom field when CustomFieldId is supplied.

    .EXAMPLE

    PS> Get-JuribaCustomField -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx"

    .EXAMPLE

    PS> Get-JuribaCustomField -Instance "https://myinstance.dpc.juriba.app" -APIKey "xxxxx" -CustomFieldId 42

    #>
    [alias("Get-DwCustomField")]

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $false)]
        [int]$CustomFieldId
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        if ($PSBoundParameters.ContainsKey('CustomFieldId')) {
            $uri = "{0}/apiv1/custom-fields/{1}" -f $Instance, $CustomFieldId
        }
        else {
            $uri = "{0}/apiv1/custom-fields" -f $Instance
        }
        $headers = @{'x-api-key' = $APIKey }
        try {
            $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType 'application/json'
            if ($result.StatusCode -eq 200) {
                return ($result.Content | ConvertFrom-Json)
            }
            else {
                Write-Error $_
            }
        }
        catch {
            Write-Error $_
        }

    }
    else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
