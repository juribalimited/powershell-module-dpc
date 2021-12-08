function Get-AuthSession {
    <#
      .SYNOPSIS
      This function is used to authenticate with Dashworks.
      .DESCRIPTION
      The function authenticates you with Dashworks and returns a WebSession that can be used with other functions in this module.
      .EXAMPLE
      Get-AuthSession -Credentials (Get-Credential) -Instance "dashworks.demo.juriba.com"
      Authenticates you with the demo instance of Dashworks.
    #>

    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true)]
        [PSCredential]$Credentials,
        [Parameter(Mandatory = $true)]
        [string]$Instance
    )

    if (-not $Credentials) {
        $Credentials = Get-Credential -Message "Enter Dashworks Credentials"
    }

    $loginForm = @{
        username = $credentials.UserName
        password = $credentials.GetNetworkCredential().Password
    }

    try {
        Invoke-RestMethod -Uri ("https://" + $Instance + ":8443/apiv1/authentication/login") -Method Post -Form $loginForm -SessionVariable session | Out-Null
    }
    catch {
        Write-Error $_.ErrorDetails.Message
        break
    }

    $session
}