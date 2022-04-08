<#

.SYNOPSIS
A sample script to query a (device or user) Dashworks list, add those items to a named
MECM collection and update a task value.

.DESCRIPTION
A sample script to query a (device or user) Dashworks list, add those items to a named
MECM collection and update a task value based on the success or failure of the collection add.
The script is designed to be run on a server with the MECM console installed.

The list used must contain the "device key" column for a device list, or a 'user key' column
for a user based list. These are required to update the task values for the objects.

The list used should contain a filter to exclude the success and failed values of the task
that is to be updated. For example, the list might pick up the "Not Started" values in an
NNSFC created task, once these have been changed to Complete or Failed, they will no longer
appear in the task

#>

[CmdletBinding()]
param (
[Parameter(Mandatory=$true)]
[string]$DwInstance,
[Parameter(Mandatory=$true)]
[string]$DwAPIKey,
[Parameter(Mandatory=$true)]
[int]$ListID,
[Parameter(Mandatory=$true)]
[int]$ProjectID,
[Parameter(Mandatory=$true)]
[int]$TaskID,
[Parameter(Mandatory=$true)]
[int]$successValue,
[Parameter(Mandatory=$true)]
[int]$failValue,
[Parameter(Mandatory=$true)]
[string]$TargetCollectionName,
[Parameter(Mandatory = $true)]
[ValidateSet("Device", "User")]
[string]$ObjectType
)

#Configure the MECM Powershell module
Set-Location "$env:SMS_ADMIN_UI_PATH\..\"
import-module '.\ConfigurationManager.psd1'

#This works for SCCM -> may need adjustment of the SMS WMI provider is not present.
$CMServer=(Get-WmiObject -class SMS_ProviderLocation -Namespace root\SMS).Machine

#Set the drive path in order to allow use of the MECM Cmdlets
$Drv = Get-PSDrive -Name "DW1" -ErrorAction SilentlyContinue
if ($null -eq $Drv)
{
    New-PSDrive -Name "DW1" -PSProvider "CMSite" -Root $CMServer -Description "Primary site"
}
Set-Location DW1:\


#Pull the list that requires processing
$List = export-DwList -Instance $APIServer -APIKey $APIKey -ListId $listID -ObjectType $ObjectType

#Get the details of the collection the items are to be added to.
$CMCollection = Get-CMCollection -Name $TargetCollectionName

forEach($row in $List)
{
    if ($ObjectType = 'Device')
    {
        $CMdevice = Get-CMDevice -Name $Row.Hostname
        #write-output "Adding $($Row.Hostname) $($CMdevice.ResourceID) to $($CMCollection.Name)"
    }
    else
    {
        $DomainUser = $Row.Domain + "\" + $Row.Username
        $CMUser = Get-CMUser -Name $DomainUser
        #write-output "Adding DomainUser $($CMUser.ResourceID) to $($CMCollection.Name)"      
    }

    
    try
    {
        #Add the object to the collection, on success set the task value to the provided success value
        if ($ObjectType = 'Device')
        {
            Add-CMDeviceCollectionDirectMembershipRule -CollectionId $CMCollection.CollectionID -ResourceId $CMdevice.ResourceID
            Set-DwRadioButtonTaskValue -Instance $APIServer -APIKey $APIKey -ObjectKey $($row.'Device Key') -ObjectType $ObjectType -TaskId $TaskID -ProjectId $ProjectID -Value $successValue
        }
        else
        {
            Add-CMUserCollectionDirectMembershipRule -CollectionId $CMCollection.CollectionID -ResourceId $CMUser.ResourceID
            Set-DwRadioButtonTaskValue -Instance $APIServer -APIKey $APIKey -ObjectKey $($row.'User Key') -ObjectType $ObjectType -TaskId $TaskID -ProjectId $ProjectID -Value $successValue
        }
    }
    catch
    {
        #On failure, set the task value to the provided fail value and continue.
        if ($ObjectType = 'Device')
        {    
            Set-DwRadioButtonTaskValue -Instance $APIServer -APIKey $APIKey -ObjectKey $($row.'Device Key') -ObjectType $ObjectType -TaskId $TaskID -ProjectId $ProjectID -Value $failValue
        }
        else
        {
            Set-DwRadioButtonTaskValue -Instance $APIServer -APIKey $APIKey -ObjectKey $($row.'User Key') -ObjectType $ObjectType -TaskId $TaskID -ProjectId $ProjectID -Value $failValue   
        }
    }
}
