function New-JuribaAutomationAction {
    [alias("New-DwAutomationAction")]
    <#
        .SYNOPSIS
        Creates a new automation action.
        .DESCRIPTION
        Creates a new automation action using Dashworks API v1.
        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443
        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.
        .PARAMETER Option
        Option to run by passing in the paramter object or by specifying the type. ByParamterObject or ByType
        .PARAMETER Name
        Name of the automation action.
        .PARAMETER AutomationId
        AutomationId for the action.
        .PARAMETER TypeId
        TypeId for the action
        .PARAMETER ProjectId
        ProjectId for the action.
        .PARAMETER IsEvergreen
        IsEvergreen flag for the action, default to false
        .PARAMETER Parameters
        It gets the structure and information of the type from the set structure
        .PARAMETER Type
        Choose from TextCustomFieldUpdate, TextCustomFieldRemove, MVTextCustomFieldAdd, Resync, UpdateProjectCapacityUnit, UpdateProjectPath, UpdateRadioButtonTask, UpdateDateTaskRelativeAnotherTask, UpdateDateTaskRelativeCurrentValue, 
            UpdateDateTaskRelativeNow, UpdateDateTask, RemoveDateTask, UpdateProjectBucket
        .PARAMETER CustomFieldId
        Custom Field Id to be assigned for action
        .PARAMETER CustomFieldValue
        Value to be assigned to the CustomField
        .PARAMETER isOwnerResync
        Boolean flag to resync owners for Resync type
        .PARAMETER isAppsResync
        Boolean flag to resync applications for Resync type
        .PARAMETER isNameResync
        Boolean flag to resync names for Resync type
        .PARAMETER UnitId
        UnitId to set to using action
        .PARAMETER AlsoMoveUsers
        Options to choose from. None, Owners only, All linked users
        .PARAMETER PathId
        PathId to update to
        .PARAMETER TaskId
        TaskId to update
        .PARAMETER RadiobuttonTaskValue
        Value to set to radio button task
        .PARAMETER DateTaskValue
        Date task value
        .PARAMETER RelativeDateTaskId
        Date task to set to relative from
        .PARAMETER RelativeDateUnit
        Date unit to set to relative from, days, weekdays
        .PARAMETER RelativeDateDays
        Number of days to set to relate from. -4 for before 4 days or 4 for after 4 days
        .OUTPUTS
        ActionId.
        .EXAMPLE
        PS> New-JuribaAutomationAction -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -Option "ByParameterObject" -Name "Update Custom Field Value" -AutomationId 1 -TypeId 1 -ProjectId 1 -IsEvergreen $false
             -Parameter 'parameters=@(@{property="TaskId";value=11;meta="task"};@{property="Value";value=2;meta="Radiobutton"};@{property="ValueActionType";value=1;meta="Radiobutton"};)'
        PS> New-JuribaAutomationAction -Instance "https://myinstance.dashworks.app:8443" -APIKey "xxxxx" -Option "ByType" -Name "Resync HWLC Owner" -AutomationId 1 -ProjectId 1 -IsEvergreen $false -Type "Resync" -isOwnerResync $true
             
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Instance,
        [Parameter(Mandatory = $false)]
        [string]$APIKey,
        [Parameter(Mandatory = $false)]
        [ValidateSet("ByParameterObject","ByType")]
        [string]$Option="ByType",
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [int]$AutomationId,
        [Parameter(Mandatory = $false)]
        [int]$TypeId,
        [Parameter(Mandatory = $false, ParameterSetName = "ByType")]
        [int]$ProjectID,
        [Parameter(Mandatory = $false)]
        [bool]$IsEvergreen = $false,
        [Parameter(Mandatory = $false)]
        [Object]$Parameters,
        [Parameter(Mandatory = $false)]
        [ValidateSet("TextCustomFieldUpdate", "TextCustomFieldRemove", "MVTextCustomFieldAdd", "Resync", "UpdateProjectCapacityUnit","UpdateProjectPath","UpdateRadioButtonTask"
                    ,"UpdateDateTaskRelativeAnotherTask","UpdateDateTaskRelativeCurrentValue","UpdateDateTaskRelativeNow","UpdateDateTask","RemoveDateTask","UpdateProjectBucket","UpdateTextTask")]
        [string]$Type,
        [Parameter(Mandatory = $false, ParameterSetName = "ByType")]
        [int]$CustomFieldId,
        [Parameter(Mandatory = $false, ParameterSetName = "ByType")]
        [string]$CustomFieldValue,
        [Parameter(Mandatory = $false, ParameterSetName = "ByType")]
        [string]$isOwnerResync = "false",
        [Parameter(Mandatory = $false, ParameterSetName = "ByType")]
        [string]$isAppsResync = "false",
        [Parameter(Mandatory = $false, ParameterSetName = "ByType")]
        [string]$isNameResync = "false",
        [Parameter(Mandatory = $false, ParameterSetName = "ByType")]
        [int]$UnitId,
        [Parameter(Mandatory = $false, ParameterSetName = "ByType")]
        [ValidateSet("None","Owners only","All linked users")]
        [string]$AlsoMoveUsers = "None",
        [Parameter(Mandatory = $false, ParameterSetName = "ByType")]
        [int]$PathId,
        [Parameter(Mandatory = $false, ParameterSetName = "ByType")]
        [int]$TaskId,
        [Parameter(Mandatory = $false, ParameterSetName = "ByType")]
        [int]$RadiobuttonTaskValue,
        [Parameter(Mandatory = $false, ParameterSetName = "ByType")]
        [datetime]$DateTaskValue,
        [Parameter(Mandatory = $false, ParameterSetName = "ByType")]
        [int]$RelativeDateTaskID,
        [Parameter(Mandatory = $false, ParameterSetName = "ByType")]
        [ValidateSet("days","weekdays")]
        [string]$RelativeDateUnit,
        [Parameter(Mandatory = $false, ParameterSetName = "ByType")]
        [int]$RelativeDateDays
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        if ($Option -eq "ByParameterObject") {
            $payload = @{}
            $payload.Add("id", -1)
            $payload.Add("name", $Name)
            $payload.Add("typeId", $TypeId)
            $payload.Add("projectId", $ProjectId)
            $payload.Add("isEvergreen", $IsEvergreen)
            
            if($Parameters) {
                $list = New-Object System.Collections.ArrayList
                $list = $Parameters
                $payload.Add("parameters", [Array]$list)
            }
        
            $jsonbody = $payload | ConvertTo-Json -Depth 6
        
            $uri = "{0}/apiv1/admin/automations/{1}/actions" -f $Instance, $AutomationId
            $headers = @{'x-api-key' = $APIKey }
        
            try {
                if ($PSCmdlet.ShouldProcess($Name)) {
                    $result = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType 'application/json'
                    if ($result.StatusCode -eq 201) {
                        $id = ($result.content | ConvertFrom-Json).id
                        return $id
                    }
                    else {
                        throw "Error creating automation action."
                    }
                }
            }
            catch {
                Write-Error $_
            }
        }
        else {
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
                            "Value"    = $CustomFieldId;
                            "meta"     = "Field"
                        },
                        @{
                            "Property" = "customFieldActionType";
                            "Value"    = 6; ## Update
                            "meta"     = "Field"
                        },
                        @{
                            "Property" = "values";
                            "Value"    = @( $CustomFieldValue )
                            "meta"     = "Field"
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
                            "Value"    = $CustomFieldId;
                            "meta"     = "Field"
                        },
                        @{
                            "Property" = "customFieldActionType";
                            "Value"    = 3; ## Remove
                            "meta"     = "Field"
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
                            "Value"    = $CustomFieldId;
                            "meta"     = "Field"
                        },
                        @{
                            "Property" = "customFieldActionType";
                            "Value"    = 1; ## Add
                            "meta"     = "Field"
                        },
                        @{
                            "Property" = "values";
                            "Value"    = @( $CustomFieldValue )
                            "meta"     = "Field"
                        }
                    )
                    $payload.Add("parameters", $params)
                    $payload.Add("isEvergreen", $false)
                }
                "Resync"
                {
                    $payload.Add("typeId", 23)
                    $payload.Add("projectId", $ProjectID)
                    $params = @(
                        @{
                            "Property" = "isOwnerResync";
                            "Value"    = $isOwnerResync;
                            "meta"     = "resync"
                        },
                        @{
                            "Property" = "isAppsResync";
                            "Value"    = $isAppsResync;
                            "meta"     = "resync"
                        },
                        @{
                            "Property" = "isNameResync";
                            "Value"    = $isNameResync;
                            "meta"     = "resync"
                        },
                        @{
                            "Property" = "isBucketResync";
                            "Value"    = "False";
                            "meta"     = "resync"
                        },
                        @{
                            "Property" = "isCapacityUnitResync";
                            "Value"    = "False";
                            "meta"     = "resync"
                        },
                        @{
                            "Property" = "isRingResync";
                            "Value"    = "False";
                            "meta"     = "resync"
                        }
                    )
                    $payload.Add("parameters", $params)
                    $payload.Add("isEvergreen", $false)
                }
                "UpdateProjectCapacityUnit" {
                    
                    switch ($AlsoMoveUsers) {
                        "None" {$moveFirstObjectActionId = 15}
                        "Owners only" {$moveFirstObjectActionId = 16}
                        "All linked users" {$moveFirstObjectActionId = 17}
                    }

                    $payload.Add("typeId", 6)
                    $payload.Add("projectId", $ProjectID)
                    $params = @(
                        @{
                            "Property" = "UnitId";
                            "Value"    = $UnitId;
                            "meta"     = "capactiy"
                        },
                        @{
                            "Property" = "moveFirstObjectActionId";
                            "Value"    = $moveFirstObjectActionId;
                            "meta"     = "capactiy"
                        }
                    )
                    $payload.Add("parameters", $params)
                    $payload.Add("isEvergreen", $false)
                }
                "UpdateProjectPath" {
                
                    $payload.Add("typeId", 1)
                    $payload.Add("projectId", $ProjectID)
                    $params = @(
                        @{
                            "Property" = "path";
                            "Value"    = $PathId;
                            "meta"     = "Request"
                        }
                    )
                    $payload.Add("parameters", $params)
                    $payload.Add("isEvergreen", $false)
                }
                "UpdateRadiobuttonTask" {
                
                    $payload.Add("typeId", 2)
                    $payload.Add("projectId", $ProjectID)
                    $params = @(
                        @{
                            "Property" = "taskId";
                            "Value"    = $TaskId;
                            "meta"     = "task"
                        },
                        @{
                            "Property" = "valueActionType";
                            "Value"    = 1; ## Update
                            "meta"     = "Radiobutton"
                        },
                        @{
                            "Property" = "value";
                            "Value"    = $RadiobuttonTaskValue;
                            "meta"     = "Radiobutton"
                        }
                    )
                    $payload.Add("parameters", $params)
                    $payload.Add("isEvergreen", $false)
                }
                "UpdateDateTaskRelativeAnotherTask" {
                
                    switch ($RelativeDateUnit) {
                        "days" {$RelativeDateUnitId = 2}
                        "weekdays" {$RelativeDateUnitId = 3}
                        Default {2} ##days
                    }

                    $payload.Add("typeId", 2)
                    $payload.Add("projectId", $ProjectID)
                    $params = @(
                        @{
                            "Property" = "taskId";
                            "Value"    = $TaskId;
                            "meta"     = "task"
                        },
                        @{
                            "Property" = "valueActionType";
                            "Value"    = 8; ## Update Relative to another task value
                            "meta"     = "Date"
                        },
                        @{
                            "Property" = "value";
                            "Value"    = $RelativeDateDays;
                            "meta"     = "Date"
                        },
                        @{
                            "Property" = "relativeTaskId";
                            "Value"    = $RelativeDateTaskID;
                            "meta"     = "Date"
                        },
                        @{
                            "Property" = "relativeProjectID";
                            "Value"    = $ProjectID;
                            "meta"     = "Date"
                        },
                        @{
                            "Property" = "relativeDateUnit";
                            "Value"    = $RelativeDateUnitId;
                            "meta"     = "Date"
                        }
                    )
                    $payload.Add("parameters", $params)
                    $payload.Add("isEvergreen", $false)
                }
                "UpdateDateTaskRelativeCurrentValue" {
                
                    switch ($RelativeDateUnit) {
                        "days" {$RelativeDateUnitId = 2}
                        "weekdays" {$RelativeDateUnitId = 3}
                        Default {2} ##days
                    }

                    $payload.Add("typeId", 2)
                    $payload.Add("projectId", $ProjectID)
                    $params = @(
                        @{
                            "Property" = "taskId";
                            "Value"    = $TaskId;
                            "meta"     = "task"
                        },
                        @{
                            "Property" = "valueActionType";
                            "Value"    = 7; ## Update Relative to current value
                            "meta"     = "Date"
                        },
                        @{
                            "Property" = "value";
                            "Value"    = $RelativeDateDays;
                            "meta"     = "Date"
                        },
                        @{
                            "Property" = "relativeDateUnit";
                            "Value"    = $RelativeDateUnitId;
                            "meta"     = "Date"
                        }
                    )
                    $payload.Add("parameters", $params)
                    $payload.Add("isEvergreen", $false)
                }
                "UpdateDateTaskRelativeNow" {
                
                    switch ($RelativeDateUnit) {
                        "days" {$RelativeDateUnitId = 2}
                        "weekdays" {$RelativeDateUnitId = 3}
                        Default {2} ##days
                    }

                    $payload.Add("typeId", 2)
                    $payload.Add("projectId", $ProjectID)
                    $params = @(
                        @{
                            "Property" = "taskId";
                            "Value"    = $TaskId;
                            "meta"     = "task"
                        },
                        @{
                            "Property" = "valueActionType";
                            "Value"    = 6; ## Update Relative to Now
                            "meta"     = "Date"
                        },
                        @{
                            "Property" = "value";
                            "Value"    = $RelativeDateDays;
                            "meta"     = "Date"
                        },
                        @{
                            "Property" = "relativeDateUnit";
                            "Value"    = $RelativeDateUnitId;
                            "meta"     = "Date"
                        }
                    )
                    $payload.Add("parameters", $params)
                    $payload.Add("isEvergreen", $false)
                }
                "UpdateDateTask" {

                    $payload.Add("typeId", 2)
                    $payload.Add("projectId", $ProjectID)
                    $params = @(
                        @{
                            "Property" = "taskId";
                            "Value"    = $TaskId;
                            "meta"     = "task"
                        },
                        @{
                            "Property" = "valueActionType";
                            "Value"    = 1; ## Update
                            "meta"     = "Date"
                        },
                        @{
                            "Property" = "value";
                            "Value"    = $DateTaskValue;
                            "meta"     = "Date"
                        }
                    )
                    $payload.Add("parameters", $params)
                    $payload.Add("isEvergreen", $false)
                }
                "RemoveDateTask" {
                    $payload.Add("typeId", 2)
                    $payload.Add("projectId", $ProjectID)
                    $params = @(
                        @{
                            "Property" = "taskId";
                            "Value"    = $TaskId;
                            "meta"     = "task"
                        },
                        @{
                            "Property" = "valueActionType";
                            "Value"    = 2; ## Remove
                            "meta"     = "Date"
                        }
                    )
                    $payload.Add("parameters", $params)
                    $payload.Add("isEvergreen", $false)
                }
				"UpdateProjectBucket" {
					
					switch ($AlsoMoveUsers) {
                        "None" {$moveFirstObjectActionId = 3}
                        "Owners only" {$moveFirstObjectActionId = 4}
                        "All linked users" {$moveFirstObjectActionId = 5}
                    }
					              
                    $payload.Add("typeId", 5)
                    $payload.Add("projectId", $ProjectID)
                    $params = @(
                        @{
                            "Property" = "bucketid";
                            "Value"    = $BucketId;
                            "meta"     = "bucket"
                        },
						@{
                            "Property" = "moveFirstObjectActionId";
                            "Value"    = $moveFirstObjectActionId;
                            "meta"     = "bucket"
                        }
                    )
                    $payload.Add("parameters", $params)
                    $payload.Add("isEvergreen", $false)
                }
				"UpdateTextTask"	{

                    $payload.Add("typeId", 2)
                    $payload.Add("projectId", $ProjectID)
                    $params = @(
                        @{
                            "Property" = "taskId";
                            "Value"    = $TaskId;
                            "meta"     = "task"
                        },
                        @{
                            "Property" = "valueActionType";
                            "Value"    = 1; #Update
                            "meta"     = "Text"
                        },
                        @{
                            "Property" = "value";
                            "Value"    = $TextTaskValue;
                            "meta"     = "Text"
                        }
                    )
                    $payload.Add("parameters", $params)
                    $payload.Add("isEvergreen", $false)	
				}
            }
        
            $jsonbody = $payload | ConvertTo-Json -Depth 6
            #Write-Host $jsonBody
        
            $uri = "{0}/apiv1/admin/automations/{1}/actions" -f $Instance, $AutomationId
            $headers = @{'x-api-key' = $APIKey }
        
            try {
                if ($PSCmdlet.ShouldProcess($Name)) {
                    $result = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonbody)) -ContentType 'application/json'
                    if ($result.StatusCode -eq 201) {
                        $id = ($result.content | ConvertFrom-Json).id
                        return $id
                    }
                    else {
                        throw "Error creating automation action."
                    }
                }
            }
            catch {
                Write-Error $_
            }
        }
    }
    else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}