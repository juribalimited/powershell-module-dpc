function Set-JuribaEvergreenSelfServicePage {
    [alias("Set-DwEvergreenSelfServicePage")]
    <#
        .SYNOPSIS
        Updates an existing self service page.
        .DESCRIPTION
        Updates an existing self service page using Dashworks API v1.
        .PARAMETER Instance
        Dashworks instance. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Dashworks API Key.
        .PARAMETER Name
        name for the self service page.
        .PARAMETER displayName
        displayName for the self service page.
        .PARAMETER PageID
        PageID of the self service page.
        .PARAMETER serviceId
        serviceId for the self service being edited.
        .PARAMETER ListId
        ListId for the self service page scope.
        .PARAMETER order
        order of the ss page.
        .PARAMETER showInSelfService
        Defaults to true.
        .PARAMETER ObjectType
        Object type that this new automation applies to. One of Device, User, Application, Mailbox.												 
        .OUTPUTS
        pageId.
        .EXAMPLE
        PS> Set-JuribaEvergreenSelfServicePage -Instance $Instance -APIKey $ApiKey -Name "My New SS4" -displayName "MyNewSS4" -Order 1 -PageID 8 -ServiceID 4 -ListId 4 -ObjectType Device
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
        [int]$PageID,
        [Parameter(Mandatory = $true)]
        [int]$serviceId,
        [Parameter(Mandatory = $true)]
        [int]$ListID,
        [Parameter(Mandatory = $false)]
        [int]$order,
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
        "order"             = $order
        "displayName"       = $displayName
        "listId"            = if ($null -eq $ListID -or $ListID -eq 0) { $null } else { $ListID }
        "showInSelfService" = $showInSelfService
    }									 

    $jsonbody = $payload | ConvertTo-Json

    $uri = "{0}/apiv1/admin/selfservicepages/{1}" -f $Instance, $PageID
    $urilist = "{0}/apiv1/lists/all/{1}/isListBrokenCommand?userAgnostic=true" -f $Instance, $Listid
    $headers = @{'x-api-key' = $APIKey }
    
    #validate listid if it is not empty
    if ($ListID -gt 0) {
        try {
            $result = Invoke-WebRequest -Uri $urilist -Method PUT -Headers $headers -ContentType 'application/json'
            #Write-host 'Scope List Validated'
        } 
        Catch {
            Write-Error "Scope list provided is not valid."
        }
    }

    #Try to update SS page
    try {
        if ($PSCmdlet.ShouldProcess($Name)) {
            $result = Invoke-WebRequest -Uri $uri -Method PUT -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType 'application/json'
            if ($result.StatusCode -eq 200)
            {
                $pageid = ($result.content | ConvertFrom-Json).pageid
                return $pageid
            }
            else {
                throw "Error updating self service page."
            }
        }
    }
    catch {
        Write-Error $_
    }
}