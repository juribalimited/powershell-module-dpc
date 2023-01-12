Function New-DwAutomationAction {
    <#
    .SYNOPSIS

    Creates a new automation.

    .DESCRIPTION

    Creates a new automation using Dashworks API v1.

    .PARAMETER Instance

    Optional. Dashworks instance to be provided if not authenticating using Connect-Dw. For example, https://myinstance.dashworks.app:8443

    .PARAMETER APIKey

    Optional. API key to be provided if not authenticating using Connect-Dw.

    .PARAMETER Name

    Name of the new automation.

    .PARAMETER AutomationId

    AutomationId for the new action.

    .PARAMETER Type

    Action Type. Accepts TextCustomFieldUpdate, TextCustomFieldRemove.

    .OUTPUTS

    ActionId.

    .EXAMPLE

    PS> New-DwAutomationAction -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -Name "Update Custom Field Value" -AutomationId 1 -Type TextCustomFieldUpdate -CustomFieldId 6 -CustomFieldValue "hello world"

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
        [int]$AutomationId,
        [Parameter(Mandatory = $true)]
        [ValidateSet("TextCustomFieldUpdate", "TextCustomFieldRemove", "MVTextCustomFieldAdd")]
        [string]$Type,
        [parameter(Mandatory = $true, ParameterSetName="TextCustomFieldUpdate")]
        [parameter(Mandatory = $true, ParameterSetName="TextCustomFieldRemove")]
        [int]$CustomFieldId,
        [parameter(Mandatory = $true, ParameterSetName="TextCustomFieldUpdate")]
        [string]$CustomFieldValue
    )
    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $payload = @{}
        $payload.Add("id", -1)
        $payload.Add("name", $Name)
    
        switch ($Type) {
            "TextCustomFieldUpdate" {
                $payload.Add("typeId", 10)
                $payload.Add("projectId", $null)
                $params = @(
                    @{
                        "Property" = "customFieldId";
                        "Value" = $CustomFieldId;
                        "meta" = "Field"
                    },
                    @{
                        "Property" = "customFieldActionType";
                        "Value" = 6; ## Update
                        "meta" = "Field"
                    },
                    @{
                        "Property" = "values";
                        "Value" = @( $CustomFieldValue )
                        "meta" = "Field"
                    }
                )
                $payload.Add("parameters", $params)
                $payload.Add("isEvergreen", $false)
                }
            "TextCustomFieldRemove" {
                $payload.Add("typeId", 10)
                $payload.Add("projectId", $null)
                $params = @(
                    @{
                        "Property" = "customFieldId";
                        "Value" = $CustomFieldId;
                        "meta" = "Field"
                    },
                    @{
                        "Property" = "customFieldActionType";
                        "Value" = 3; ## Remove
                        "meta" = "Field"
                    }
                )
                $payload.Add("parameters", $params)
                $payload.Add("isEvergreen", $false)
                }
            "MVTextCustomFieldAdd" {
                $payload.Add("typeId", 10)
                $payload.Add("projectId", $null)
                $params = @(
                    @{
                        "Property" = "customFieldId";
                        "Value" = $CustomFieldId;
                        "meta" = "Field"
                    },
                    @{
                        "Property" = "customFieldActionType";
                        "Value" = 1; ## Add
                        "meta" = "Field"
                    },
                    @{
                        "Property" = "values";
                        "Value" = @( $CustomFieldValue )
                        "meta" = "Field"
                    }
                )
                $payload.Add("parameters", $params)
                $payload.Add("isEvergreen", $false)
                }
        }
    
        $jsonbody = $payload | ConvertTo-Json -Depth 6
    
        $uri = "{0}/apiv1/admin/automations/{1}/actions" -f $Instance, $AutomationId
        $headers = @{'x-api-key' = $APIKey }
    
        try {
            if ($PSCmdlet.ShouldProcess($Name)) {
                $result = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $jsonbody -ContentType 'application/json'
                if ($result.StatusCode -eq 201)
                {
                    $id = ($result.content | ConvertFrom-Json).id
                    return $id
                }
                else {
                    throw "Error creating automation."
                }
            }
        }
        catch {
                Write-Error $_
        }

    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Dw before proceeding."
    }
}
