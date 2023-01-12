Function New-DwTag {
    <#
    .SYNOPSIS

    Creates a new list tag.

    .DESCRIPTION

    Creates a new list tag using Dashworks API v1.

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $body = @{
            tag = $Name
        } | ConvertTo-Json
    
        $uri = "{0}/apiv1/tags" -f $Instance
        $headers = @{ 'x-api-key' = $APIKey }
    
        try {
            if ($PSCmdlet.ShouldProcess($Name)) {
                $result = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $body -ContentType 'application/json'
                return ($result.Content | ConvertTo-Json)
            }
        }
        catch {
                Write-Error $_
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
