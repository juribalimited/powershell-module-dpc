function New-CustomField {
    <#
    .SYNOPSIS

    Creates a new custom field.

    .DESCRIPTION

    Creates a new custom field using the Dashworks API v1.

    .PARAMETER DashworksSession

    Hash table containing Domain, Port and API Key for your Dashworks instance.

    .PARAMETER Name

    Name of the new custom field.

    .PARAMETER CSVColumnHeader

    CSV Column Header for the new custom field. Restricted to alphanumeric characters.

    .PARAMETER Type

    Type of the new custom field. One of Text, MultiText, LargeText, Number or Date.

    .PARAMETER ObjectTypes

    Object types that this new custom field applies to. Accepts multiple selections. One or more of Device, User, Application, Mailbox.

    .PARAMETER IsActive

    Set the new custom field to active or inactive. Defaults to Active.

    .INPUTS

    None. You cannot pipe objects to Add-Extension

    .OUTPUTS

    None.

    .EXAMPLE

    PS> New-CustomField -ObjectTypes Device, User -Name "MyNewCustomField" -CSVColumnHeader "mynewcustomdfield" -Type Text -IsActive $true -DashworksSession $DashworksSession

    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        "PSUseShouldProcessForStateChangingFunctions",
        "",
        Justification = "API endpoint does not support ShouldProcess."
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Collections.Hashtable]$DashworksSession,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$CSVColumnHeader,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Text", "MultiText", "LargeText", "Number", "Date")]
        [string]$Type,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Device", "User", "Application", "Mailbox")]
        [string[]]$ObjectTypes,
        [Parameter(Mandatory=$false)]
        [bool]$IsActive = $true
    )

    $TypeId = switch($Type) {
        "Text"      {1}
        "MultiText" {2}
        "LargeText" {3}
        "Number"    {5}
        "Date"      {4}
    }

    $payload = @{}
    $payload.Add("allowExternalUpdate", $true)
    $payload.Add("csvUpdateColumnHeader", $CSVColumnHeader)
    $payload.Add("IsActive", $IsActive)
    $payload.Add("isApplicationField", ($ObjectTypes -contains "Application"))
    $payload.Add("isComputerField", ($ObjectTypes -contains "Device"))
    $payload.Add("isMailboxField",($ObjectTypes -contains "Mailbox"))
    $payload.Add("isUserField", ($ObjectTypes -contains "User"))
    $payload.Add("name", $Name)
    $payload.Add("valueTypeId", $TypeId)

    $jsonbody = $payload | ConvertTo-Json
    $uri = "https://{0}:{1}/apiv1/custom-fields" -f $DashworksSession.Domain, $DashworksSession.Port
    $headers = @{'x-api-key' = $DashworksSession.APIKey }

    try {
        $result = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $jsonbody -ContentType 'application/json'
        if ($result.StatusCode -eq 200) {
            Write-Information "Custom field created" -InformationAction Continue
        }
        else {
            throw "Error in custom field creation"
        }
    }
    catch {
        if ($_.Exception.Response.StatusCode.Value__ -eq 409)
        {
            Write-Error ("{0}" -f (($_ | ConvertFrom-Json).detail))
            break
        }
        else
        {
            Write-Error ("{0}. {1}" -f $_.Exception.Response.StatusCode.Value__, ($_ | ConvertFrom-Json).details)
            break
        }
    }
}
