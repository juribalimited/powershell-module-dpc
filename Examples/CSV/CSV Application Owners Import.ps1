<#
.SYNOPSIS
A sample script to link the application owners to an application from a CSV in Juriba.

.DESCRIPTION
A sample script to link the application owners to an application from a CSV in Juriba.
This script uses the application key and username of the user from the CSV and links it
to the application in Juriba. This script is designed to run against an individual
project in Juriba.

.Parameter Instance
The URI to the Dashworks instance being examined.

.Parameter APIKey
The APIKey for a user with access to the required resources.

.Parameter ProjectId
The Project ID of the project the application owners should be updated against.

.Parameter CSVPath
The full path of where the CSV containing the application owners resides, including the 
CSV name. For example, C:\Temp\AppOwners.csv.

.Parameter UserListId
The List ID from the Juriba platform containing the list of users in the project, 
containing the User Key. 
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$Instance,
    [Parameter(Mandatory=$true)]
    [string]$APIKey,
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,
    [Parameter(Mandatory = $true)]
    [string]$CSVPath,
    [Parameter(Mandatory = $true)]
    [string]$UserListId
    )

    # Get data from CSV file
    $csvFile = Import-Csv -Path $CSVPath | Select-Object *, UserKey
    $csvCount = $csvFile.Count
    Write-Host "******* The CSV file contains $csvCount rows *******"

    #Set the Headers
    $contentType = "application/json"
    $headers = @{'X-API-KEY' = $ApiKey
    }

    #Get list of users from Dashworks
    $Usersuri = '{0}/apiv1/users?$listid={1}' -f $Instance, $UserListId
    $Usersheaders = @{'X-API-KEY' = $ApiKey
    }

    $response = Invoke-WebRequest -uri $Usersuri -Headers $Usersheaders -Method GET
    $users = ($response.Content | ConvertFrom-Json).results
    $usersCount = $users.Count
    Write-Host "******* The user report contains $usersCount users *******"

    #Add the user object key to the CSV file results
    foreach ($line in $csvFile){
        $users | Where-Object{$_.username -eq $line."Owner Username"} | ForEach-Object{$line.Userkey=$_.ObjectKey}
    }

    #Process each application in the CSV
    $i = 0
    foreach ($line in $csvFile){
        $i++
        $ProgressPreference = 'SilentlyContinue'
        #Add the payload in a JSON format for the URL
        $Appbody = @{
            "projectId"                 = $ProjectId
            "IsChangeOwner"             = "true"
            "objectId"                  = $line.UserKey
        } | ConvertTo-Json

        #Get the application key to add to the URL
        $AppId = $line."Application Key"

        #Set the URL
        $uri = "{0}/apiv1/application/$AppId/updateObjectOwner" -f $Instance

        #Process the results
        try{
            $Results = Invoke-WebRequest -Uri $uri -Headers $headers -Body $Appbody -Method POST -ContentType $contentType
            Write-Host "Application Key $AppId successfully processed"
        }
        catch{
            Write-Host "Application Key $AppId is not part of the project or the user $($line."Owner Username") is not in the project"
        }
        $ProgressPreference = 'Continue'
    }

Write-Host "******* This script has successfully completed *******"