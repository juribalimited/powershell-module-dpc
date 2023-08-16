function New-JuribaEvergreenSelfServicePage {
    [alias("New-DwEvergreenSelfServicePage")]
    <#
        .SYNOPSIS
        Creates a new self service page.
        .DESCRIPTION
        Creates a new self service page using Dashworks API v1.
        .PARAMETER Instance
        Dashworks instance. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Dashworks API Key.
        .PARAMETER name
        name for the self service page.
        .PARAMETER displayName
        displayName for the self service page.
        .PARAMETER serviceId
        serviceId for the self service being edited.
        .PARAMETER ListId
        ListId for the self service page scope.
        .PARAMETER showInSelfService
        Defaults to true.
        .PARAMETER ObjectType
        Object type that this new automation applies to. One of Device, User, Application, Mailbox.					 
        .OUTPUTS
        pageId.
        .EXAMPLE
        PS> New-JuribaEvergreenSelfServicePage @dwparams -Name "test4" -displayName "test4d" -serviceid 2 -ListID 63 -showInSelfService $true -ObjectType "user"
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
        [string]$displayName,
        [Parameter(Mandatory = $true)]
        [int]$serviceId,
        [Parameter(Mandatory = $true)]
        [int]$ListID,
        [Parameter(Mandatory = $false)]
        [bool]$showInSelfService = $true,
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

    $payload  = @{
        "name"              = $Name
        "serviceId"         = $serviceId
        "objectTypeId"      = $objectTypeId
        "displayName"       = $displayName
        "listId"            = if ($null -eq $ListID -or $ListID -eq 0) { $null } else { $ListID }
        "showInSelfService" = $showInSelfService
    }

    $jsonbody = $payload | ConvertTo-Json

    $uri = "{0}/apiv1/admin/selfservicepages" -f $Instance
    $urilist = "{0}/apiv1/lists/all/{1}/isListBrokenCommand?userAgnostic=true" -f $Instance, $ListID
    $headers = @{'x-api-key' = $APIKey }
    
    #validate listid
    if ($ListID -gt 0) {
        try {
            $result = Invoke-WebRequest -Uri $urilist -Method PUT -Headers $headers -ContentType 'application/json'
            #Write-host 'Scope List Validated'
        } 
        Catch {
            Write-Error "Scope list provided is not valid."
        }
    }

    #Try to create SS page
    try {
        if ($PSCmdlet.ShouldProcess($Name)) {
            $result = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType 'application/json'
            if ($result.StatusCode -eq 200)
            {
                $pageid = ($result.content | ConvertFrom-Json).pageid
                return $pageid
            }
            else {
                throw "Error creating self service page."
            }
        }
    }
    catch {
        Write-Error $_																													   
    }
}