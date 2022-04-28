#Requires -Version 7.0

<#
.SYNOPSIS
A sample script to query a deviceapplication Dashworks list and add devices to application groups.

.DESCRIPTION
A sample script to query a device application Dashworks list, look up the ad group related to the application
from a taskID and add the device to the group in question.
The script is designed to be run on a server ActiveDirectory RSAT powershell module installed.
The list used must contain the "app key" column. This is required to get the task values for that objects.
In normal usage the list used should contain a filter to exclude the success and failed values of the task
for devices to be updated. For example, the list might pick up the "Not Started" values in an
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
[Parameter(Mandatory = $true)]
[ValidateSet("Device", "User")]
[string]$ObjectType
)

$ObjectTypeApplication = switch($ObjectType) {
    "Device" {"deviceapplications"}
    "User"   {"userapplications"}
}

$List = Export-DwList -Instance $DwInstance -APIKey $DwAPIKey -ListId $listID -ObjectType $ObjectTypeApplication

$AppKeys = (($List | select-object -Property "Application Key" -Unique).'Application Key')

$AppKeys | foreach-Object -Parallel {
    
    $AppKey=$_
    $uri = '{0}/apiv1/application/{1}/getProjectTasks?projectId={2}&$lang=en-GB' -f $using:DwInstance,$AppKey,$using:ProjectID
    $headers = @{'x-api-key' = $using:DwAPIKey}

    try
    {
        #write-output $uri
        $TaskReturn = Invoke-WebRequest -uri $uri -Headers $headers -Method GET
        $TaskValue = (($TaskReturn.Content | ConvertFrom-Json).results | Where-Object {$AppKey.TaskID -eq $AppGrpTaskID}).value.value
        ($using:AppGroups).Add("app$AppKey",$TaskValue)
        write-output "AppKey $AppKey has $TaskValue"
    }
    catch
    {
        write-output "AppKey $AppKey does not exist in the project"
    }
}

#Add the objects to the AD Groups given in the task
foreach($Row in $List)
{
    if ($null -ne $AppGroups[$Row.'Application Key'])
    {
        if ($ObjectType -eq 'Device')
        {
            $ObjectName = $($Row.Hostname + '$')
        }
        else {
            $ObjectName = $Row.Username
        }

        try
        {
            write-output "Adding $ObjectType $ObjectName to group $($AppGroups[$Row.'Application Key'])"
            Add-ADGroupMember -Identity $AppGroups[$Row.'Application Key'] -members $ObjectName
        }
        catch
        {
            write-error $_
        }
    }
    else
    {
        write-output "$ObjectType ObjectName - no group found for App: $($Row.'Application Name')"
    }
}