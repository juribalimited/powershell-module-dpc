function New-DwCustomField {
    <#
    .SYNOPSIS

    Creates a new custom field.

    .DESCRIPTION

    Creates a new custom field using the Dashworks API v1.

    .PARAMETER Instance

    Dashworks instance. For example, myinstance.dashworks.app

    .PARAMETER Port

    Dashworks API port number. Default = 8443

    .PARAMETER APIKey

    Dashworks API Key.

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

    .OUTPUTS

    None.

    .EXAMPLE

    PS> New-DwCustomField -ObjectTypes Device, User -Name "MyNewCustomField" -CSVColumnHeader "mynewcustomfield" -Type Text -IsActive $true -Instance "myinstance.dashworks.app" -APIKey "xxxxx"

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [int]$Port = 8443,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
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

    $typeId = switch($Type) {
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
    $payload.Add("valueTypeId", $typeId)

    $jsonbody = $payload | ConvertTo-Json
    $uri = "https://{0}:{1}/apiv1/custom-fields" -f $Instance, $Port
    $headers = @{'x-api-key' = $APIKey }

    try {
        if ($PSCmdlet.ShouldProcess($Name)) {
            $result = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $jsonbody -ContentType 'application/json'
            if ($result.StatusCode -eq 200) {
                Write-Information "Custom field created" -InformationAction Continue
            }
            else {
                throw "Error in custom field creation"
            }
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