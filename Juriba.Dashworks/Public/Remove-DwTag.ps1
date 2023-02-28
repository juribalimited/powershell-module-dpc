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
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [string]$Tag
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
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

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}