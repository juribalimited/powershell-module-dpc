function New-JuribaEvergreenSelfService {
    [alias("New-DwEvergreenSelfService")]
    <#
        .SYNOPSIS
        Creates a new self service.
        .DESCRIPTION
        Creates a new self service using Dashworks API v1.
        .PARAMETER Instance
        Dashworks instance. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Dashworks API Key.
        .PARAMETER Name
        Name of the new self service.
        .PARAMETER ShortName
        ShortName for the the self service.
        .PARAMETER ScopeId
        ListId for the self service scope.
        .PARAMETER enabled
        Set the new self service to active or inactive. Defaults to True.
        .PARAMETER allowAnonymousUsers
        Defaults to true.
        .PARAMETER ObjectType
        Object type that this new automation applies to. One of Device, User, Application, Mailbox.
        .OUTPUTS
        serviceId.
        .EXAMPLE
        PS> New-JuribaEvergreenSelfService -Instance $Instance -APIKey $ApiKey -Name "My New SS3" -ShortName "MyNewSS3" -scopeId 4 -enabled $true -allowAnonymousUsers $true -ObjectType Device
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$ShortName,
        [Parameter(Mandatory = $true)]
        [int]$scopeId,
        [Parameter(Mandatory = $false)]
        [bool]$enabled = $true,
        [Parameter(Mandatory = $false)]
        [bool]$allowAnonymousUsers = $true,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Device", "User", "Application", "Mailbox")]
        [string]$ObjectType
    )

    $objectTypeId = switch ($ObjectType) {
        "Device"        { 2 }
        "User"          { 1 }
        "Application"   { 3 }
        "Mailbox"       { 4 }
    }

    $payload  = @{}
    $payload.Add("serviceId", -1)
    $payload.Add("scopeId", $scopeId)
    $payload.Add("name", $Name)
    $payload.Add("serviceShortName", $ShortName)
    $payload.Add("objectTypeId", $objectTypeId)
    $payload.Add("enabled", $enabled)
    $payload.Add("allowAnonymousUsers", $allowAnonymousUsers)

    $jsonbody = $payload | ConvertTo-Json

    $uri = "{0}/apiv1/admin/selfservices/default" -f $Instance
    $uriscope = "{0}/apiv1/lists/all/{1}/isListBrokenCommand?userAgnostic=true" -f $Instance, $scopeId
    $headers = @{'x-api-key' = $APIKey }
    
    #validate scopelistid
    if ($scopeId -gt 0) {
        try {
            $validate = Invoke-WebRequest -Uri $uriscope -Method PUT -Headers $headers -ContentType 'application/json'
            #Write-host 'Scope List Validated'
        } 
        Catch {
            Write-host "Scope list provided is not valid."
            Write-Error $_
            throw
        }
    }

    #Try to create SS
    try {
        if ($PSCmdlet.ShouldProcess($Name)) {
            $result = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType 'application/json'
            if ($result.StatusCode -eq 200)
            {
                $serviceId = ($result.content | ConvertFrom-Json).serviceId
                return $serviceId
            }
            else {
                throw "Error creating self service."
            }
        }
    }
    catch {
            Write-Error $_
    }
}