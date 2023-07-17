function Set-JuribaEvergreenSelfService {
    [alias("Set-DwEvergreenSelfService")]
    <#
        .SYNOPSIS
        Updates the Evergreen SelfService.
        .DESCRIPTION
        Updates the Evergreen SelfService using Dashworks API v1.
        .PARAMETER Instance
        Dashworks instance. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Dashworks API Key.
        .PARAMETER ServiceID
        ServiceID for the self service.
        .PARAMETER ScopeID
        ScopeID for the self service.
        .PARAMETER ServiceName
        ServiceName for the self service.
        .PARAMETER ServiceShortName
        ServiceShortName for the self service.
        .PARAMETER ObjectType
        ObjectType for the self service.
        .PARAMETER Enabled
        Set Active or Inactive for the self service.
        .OUTPUTS
        Self service details have updated successfully
        .EXAMPLE
        PS> Set-JuribaEvergreenSelfService @dwparams -ServiceID 20 -ScopeID 115 -ServiceName 'W11 Deployment' -ServiceShortName 'W11-App' -ObjectType 'Device' -Enabled $true
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [int]$ServiceID,
        [Parameter(Mandatory = $true)]
        [int]$ScopeID,
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,
        [Parameter(Mandatory = $true)]
        [string]$ServiceShortName,
        [Parameter(Mandatory = $true)]
        [string]$ObjectType,
        [Parameter(Mandatory = $true)]
        [bool]$Enabled
    )

    $objectTypeId = switch ($ObjectType) {
        "Device"        { 2 }
        "User"          { 1 }
        "Application"   { 3 }
        "Mailbox"       { 4 }
    }

    $payload = @{}
    $payload.Add("serviceId", $ServiceID)
    $payload.Add("scopeId", $ScopeID)
    $payload.Add("name", $ServiceName)
    $payload.Add("serviceShortName", $ServiceShortName)
    $payload.Add("objectTypeId", $ObjectTypeID)
    $payload.Add("enabled", $Enabled)
    $payload.Add("allowAnonymousUsers", $true)

    $jsonbody = $payload | ConvertTo-Json    

    $uri = "{0}/apiv1/admin/selfservices/{1}" -f $Instance, $ServiceID
    $uriscope = "{0}/apiv1/lists/all/{1}/isListBrokenCommand?userAgnostic=true" -f $Instance, $ScopeID
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

    #Try to update SS
    try {
        $result = Invoke-WebRequest -Uri $uri -Method PUT -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType 'application/json'
        if ($result.StatusCode -eq 200)
        {
            return "Self service details have updated successfully"
        }
        else {
            throw "Error updating self service."
        }
    }
    catch {
            Write-Error $_
    }
}