function Get-JuribaProject {
    [alias("Get-DwProject")]
    <#
           .SYNOPSIS
           Returns all projects in US English.
           .DESCRIPTION
           Returns all project details as an array.
           Takes no inputs except authentication
           .PARAMETER Instance
           Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
           .PARAMETER APIKey
           Optional. API key to be provided if not authenticating using Connect-Juriba.
           .EXAMPLE
           PS> Get-Projects @DwParams
       #>
   
       [CmdletBinding(DefaultParameterSetName="Default")]
       param (
           [Parameter(Mandatory=$false)]
           [string]$Instance,
           [Parameter(Mandatory=$false)]
           [string]$APIKey
       )
   
       $uri = "$instance/apiv1/admin/projects/allProjects?$lang=en-US"
       $headers = @{
           'x-api-key' = $APIKey
           'cache-control' = 'no-cache'
       }
       try {
               $result = Invoke-WebRequest -Uri $Uri -Method GET -Headers $headers -ContentType "application/json" -SkipCertificateCheck
               return ($result.content | ConvertFrom-Json).results
       } Catch 
       {Write-Error $_}
   }