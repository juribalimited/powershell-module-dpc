function Set-JuribaEvergreenSelfServiceComponent {
    [alias("Set-DwEvergreenSelfServiceComponent")]
    <#
        .SYNOPSIS
        Update a new self service component.
        .DESCRIPTION
        Creates a new self service component using Dashworks API v1.
        .PARAMETER Instance
        Dashworks instance. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Dashworks API Key.
        .PARAMETER ComponentName
        name for the self service component.
        .PARAMETER ServiceId
        ServiceId for the component to be added.
        .PARAMETER ComponentId
        ComponentId for the component to be added.
        .PARAMETER PageId
        PageId for the self service page the component is being added.
        .PARAMETER ComponentType
        Component type that this new automation applies to. One of Text, Application Ownership, Device Ownership, Task, List Task, Text Task, Location, Attribute, Application.
        .PARAMETER ExtraProperties
        Content of the html being displayed.
        .PARAMETER order
        order of the component being displayed on the page.
        .PARAMETER ShowInSelfService
        Defaults to true.
        .PARAMETER Translations
        Content of the component in addition to ExtraProperties
        .PARAMETER helpText
        Typically contains "help_text" or defaults to null
        .PARAMETER ComponentTypeDescription
        Typically contains the text "ComponentTypeDescription"
        .OUTPUTS
        componentId.
        .EXAMPLE
        PS> Set-JuribaEvergreenSelfServiceComponent @dwparams -ComponentName "test4" -ServiceId 2 -ComponentId 11 -PageId 3 -ComponentType "Text" -ExtraProperties "@{text = ''}" order 1 -ShowInSelfService $true -Translations 
             @{languageId = "0" ; languageName = "English" ; isDefault = $true ; translation = '<p>This is your text</p>' ; pageId = 0 ; componentId = 0 ; subComponentTypeId = 1 } -helpText "help_text"
             -ComponentTypeDescription "ComponentTypeDescription"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([int32])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [string]$ComponentName,
        [Parameter(Mandatory = $true)]
        [int]$ServiceId,
        [Parameter(Mandatory = $true)]
        [int]$ComponentId,
        [Parameter(Mandatory = $true)]
        [int]$PageId,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Text", "Application Ownership", "Device Ownership", "Task", "List Task", "Text Task", "Location", "Attribute", "Application")]
        [string]$ComponentType,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ExtraProperties,
        [Parameter(Mandatory = $false)]
        [int]$order,
        [Parameter(Mandatory = $false)]
        [bool]$ShowInSelfService = $true,
        [Parameter(Mandatory = $false)]
        [Object[]]$Translations,
        [Parameter(Mandatory = $false)]
        [string]$helpText = $null,
        [Parameter(Mandatory = $false)]
        [string]$ComponentTypeDescription
    )

    $ComponentTypeId = switch ($ComponentType) {
        "Text"						{ 1 }
        "Application Ownership"		{ 2 }
        "Device Ownership"			{ 3 }
        "Task"						{ 4 }
        "List Task"					{ 5 }
        "Text Task"					{ 6 }
        "Location"					{ 7 }
        "Attribute"					{ 8 }
        "Application"				{ 9 }
    }

    $headers = @{'x-api-key' = $APIKey }

    # Payload to create SS component
    $cpayload = @{}
    $cpayload.Add("componentId", $ComponentId)
    $cpayload.Add("componentName", $ComponentName)
    $cpayload.Add("pageId", $PageId)
    $cpayload.Add("componentTypeId", $ComponentTypeId)   

    if($ExtraProperties) {
        $cpayload.Add("extraProperties", $ExtraProperties)
    }

    $cpayload.Add("order", $Order)
    $cpayload.Add("showInSelfService", $ShowInSelfService)

    if($helpText) {
        $cpayload.Add("helpText", $helpText)
    }
    else {
        $cpayload.Add("helpText", $null)
    }

    if($ComponentTypeDescription) {
        $cpayload.Add("componentTypeDescription", $ComponentTypeDescription)
    }

    $cjsonbody = $cpayload | ConvertTo-Json -Depth 6
    $curi = "{0}/apiv1/admin/selfservicecomponents/{1}" -f $Instance, $ComponentId
    $turi = "{0}/apiv1/admin/selfservices/{1}/translations" -f $Instance, $ServiceId
    
    #Try to create SS component
    try {
        if ($PSCmdlet.ShouldProcess($ComponentName)) {
            $result = Invoke-WebRequest -Uri $curi -Method PUT -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($cjsonbody)) -ContentType 'application/json'

            if ($result.StatusCode -eq 200)
            {
                if(($result.content | ConvertFrom-Json).componentid -eq $ComponentId) {
                    try {
                        if($Translations) {
                            $Translations.ForEach('componentId', $ComponentId)
                            $tpayload = @{}
                            $tlist = New-Object System.Collections.ArrayList
                            $tlist = $Translations
                            $tpayload.Add("translations", $tlist)                            
                            $tjsonbody = $tpayload | ConvertTo-Json -Depth 6
                            $result = Invoke-WebRequest -Uri $turi -Method PUT -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($tjsonbody)) -ContentType 'application/json'
                        }                    
                        return $componentid
                    }
                    catch {
                        Write-Error $_
                    }
                }
            }
            else {
                throw "Error updating self service component."
            }
        }
    }
    catch {
        Write-Error $_
    }
}