<#

.SYNOPSIS
A sample script that enriches MECM data within Juriba platform with AppM test data

.DESCRIPTION
Enriches existing MECM data within a defined Import ID in Juriba platform with AppM test data. Matches data against the unique identifier between Juriba platform and AppM.
Must update variables below appropriately. Script will work for on-premise or Cloud installations of Juriba provided access to MECM instance is possible.
Must add the following custom fields into Juriba platform BEFORE using this script:

New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - App Name' -CSVColumnHeader 'AppM - App Name' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - App Version' -CSVColumnHeader 'AppM - App Version' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Direct Link' -CSVColumnHeader 'AppM - Direct Link' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Test Status' -CSVColumnHeader 'AppM - Test Status' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Test Result' -CSVColumnHeader 'AppM - Test Result' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Test OS' -CSVColumnHeader 'AppM - Test OS' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - App Manufacturer' -CSVColumnHeader 'AppM - App Manufacturer' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Virtual Machine Name' -CSVColumnHeader 'AppM - Virtual Machine Name' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Test Time Taken' -CSVColumnHeader 'AppM - Test Time Taken' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Test Start Time' -CSVColumnHeader 'AppM - Test Start Time' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'AppM - Old Test Data' -CSVColumnHeader 'AppM - Old Test Data' -Type LargeText -ObjectTypes Application -AllowUpdate 'ETL'

New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'CI_UniqueID' -CSVColumnHeader 'CI_UniqueID' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'
New-JuribaCustomField -Instance $dwInstance -APIKey $dwToken -Name 'PackageID' -CSVColumnHeader 'PackageID' -Type Text -ObjectTypes Application -AllowUpdate 'ETL'

#>

#requires -Modules @{ ModuleName="Juriba.Platform"; ModuleVersion="0.0.39.0" }

$dwAppImportFeedName = "<<IMPORT FEED NAME>>"
$dwInstance = "https://change-me-juriba-fqdn.com:8443"
$dwToken = "<<CHANGE ME>>"

$reqCustomFields = @("AppM - App Name","AppM - App Version", "AppM - Direct Link", "AppM - Test Status", "AppM - Test Result", "AppM - Test OS", "AppM - App Manufacturer", "AppM - Virtual Machine Name", "AppM - Test Time Taken", "AppM - Test Start Time", "AppM - Old Test Data", "CI_UniqueID", "PackageID")
$customFields = Get-JuribaCustomField -Instance $dwInstance -APIKey $dwToken
foreach ($customField in $reqCustomFields) {
    if ($customField -notin $customFields.name) {
        Write-Error "Custom field: $customField missing from Juriba platform instance. Please onboard before proceeding."
    }
}
$feed = Get-JuribaImportDeviceFeed -Instance $dwInstance -APIKey $dwToken -Name $dwAppImportFeedName
if ($null -eq $feed) {
    Write-Error "Could not find Juriba import feed with name: $dwAppImportFeedName"
    Exit
}
##############
# AppM stuff #
##############
$appMInstance = "https://change-me-appm-fqdn.com/"
$appMToken = "<<CHANGE ME>>"

$appMMecmList = New-Object System.Collections.Generic.List[System.Object]

#Auth using x-api-key now instead of Bearer token
$appMHeaders = @{
    "x-api-key" = "$appMToken"
}

$appMApps = "api/apm/applications/listOfAppsV2/false"
$appMAceAppById = "api/ace/application"
$appMTestData = "api/apm/application"

$appsResponse = Invoke-WebRequest -Uri "$appMInstance$appMApps" -Method GET -Headers $appMHeaders -ContentType "application/json"
$appsObj = $appsResponse.content | ConvertFrom-Json

foreach ($app in $appsObj) {
        $testEnvData = Invoke-WebRequest -Uri "$appMInstance$appMTestData/$($app.basic.appId)" -Method GET -Headers $appMHeaders -ContentType "application/json"
        $testEnvDataObj = $($testEnvData.content | ConvertFrom-Json)

        $evergreenData = Invoke-WebRequest -Uri "$appMInstance$appMAceAppById/$($app.basic.appId)/clean" -Method GET -Headers $appMHeaders -ContentType "application/json"
        $evergreenDataObj = $($evergreenData.content | ConvertFrom-Json)

        if ($app.basic.appId -match $testEnvDataObj.basic.appId) {
            $app | Add-Member -MemberType NoteProperty -Name "TestSettings" -Value $testEnvDataObj.ext -Force
            $app | Add-Member -MemberType NoteProperty -Name "PackagingData" -Value $testEnvDataObj.packagingInfo -Force
        }
        if ($app.basic.appId -match ($evergreenDataObj.applicationId | Select-Object -First 1)) {

            $app | Add-Member -MemberType NoteProperty -Name "TestData" -Value $evergreenDataObj.evergreenInformation -Force
            $app | Add-Member -MemberType NoteProperty -Name "TestAppManufacturer" -Value $evergreenDataObj.manufacturer -Force
            $app | Add-Member -MemberType NoteProperty -Name "TestAppName" -Value $evergreenDataObj.applicationName -Force
            $app | Add-Member -MemberType NoteProperty -Name "TestAppVersion" -Value $evergreenDataObj.applicationVersion -Force
        }
        $appMMecmList.Add($app)
    }
Write-Host "Total AppM apps found: $($appMMecmList.Count)"

$headers = @{'x-api-key' = $dwToken}
$uri = "$dwInstance/apiv2/imports/applications/$($feed.id)/items?limit=1000"
$jrbAppList = (Invoke-WebRequest -Uri $uri -Method GET -Headers $headers -ContentType "application/json").content | ConvertFrom-Json

foreach ($appMApp in $appMMecmList) {        
    foreach ($jrbApp in $jrbAppList) {
        if (($appMApp.originalApplicationId -match $jrbApp.uniqueIdentifier) -or ($jrbApp.uniqueIdentifier -match $appMApp.originalApplicationId) -and ($appMApp.originalApplicationId -ne $null)) {
            Write-Host "MECM match found for $($appMApp.originalApplicationId)"
            Write-Host "Onboarding Test Data from AppM to Juriba platform for $($jrbApp.manufacturer) - $($jrbApp.name)"
            if($appMApp.TestData.Length -eq 1) {
                $json = @{
                    customFieldValues = @(
                        @{
                            name = "AppM - App Manufacturer"
                            value = "$($appMApp.basic.manufacturer)"
                        },
                        @{
                            name = "AppM - App Name"
                            value = "$($appMApp.basic.name)"
                        },
                        @{
                            name = "AppM - App Version"
                            value = "$($appMApp.basic.packageVersion)"
                        },
                        @{
                            name = "AppM - Direct Link"
                            value = '<a href="' + $appMInstance + 'app/applications/fullStatus/' + $($appMApp.basic.appId) + '/9" >' + $($appMApp.TestData.status) + '</a>'
                        },
                        @{
                            name = "AppM - Test Status"
                            value = "$($appMApp.TestData.status)"
                        },
                        @{
                            name = "AppM - Test Result"
                            value = "$($appMApp.TestData.information)"
                        },
                        @{
                            name = "AppM - Test OS"
                            value = "$($appMApp.TestData.operatingSystem.operatingSystemName)"
                        },
                        @{
                            name = "AppM - Virtual Machine Name"
                            value = "$($appMApp.TestData.virtualMachineName)"
                        },
                        @{
                            name = "AppM - Test Time Taken"
                            value = "$($appMApp.TestData.testingTimeTakenString)"
                        },
                        @{
                            name = "AppM - Test Start Time"
                            value = "$($appMApp.TestData.testingStart)"
                        }
                    )
                } 
            } elseif ($appMApp.TestData.Length -gt 1) {
                [System.Collections.ArrayList]$oldTestData = $appMApp.TestData
                $oldTestData.removeAt($appMApp.TestData.Length-1)
                $oldTestDataString = $oldTestData | Out-String

                $json = @{
                    customFieldValues = @(
                        @{
                            name = "AppM - App Manufacturer"
                            value = "$($appMApp.basic.manufacturer)"
                        },
                        @{
                            name = "AppM - App Name"
                            value = "$($appMApp.basic.name)"
                        },
                        @{
                            name = "AppM - App Version"
                            value = "$($appMApp.basic.packageVersion)"
                        },
                        @{
                            name = "AppM - Direct Link"
                            value = '<a href="' + $appMInstance + 'app/applications/fullStatus/' + $($appMApp.basic.appId) + '/9" >' + $($appMApp.TestData.status) + '</a>'
                        },
                        @{
                            name = "AppM - Test Status"
                            value = $($appMApp.TestData.status)[$($appMApp.TestData.status).Count-1]
                        },
                        @{
                            name = "AppM - Test Result"
                            value = $($appMApp.TestData.information)[$($appMApp.TestData.information).Count-1]
                        },
                        @{
                            name = "AppM - Test OS"
                            value = $($appMApp.TestData.operatingSystem.operatingSystemName)[$($appMApp.TestData.operatingSystem.operatingSystemName).Count-1]
                        },
                        @{
                            name = "AppM - Virtual Machine Name"
                            value = $($appMApp.TestData.virtualMachineName)[$($appMApp.TestData.virtualMachineName).Count-1]
                        },
                        @{
                            name = "AppM - Test Time Taken"
                            value = $($appMApp.TestData.testingTimeTakenString)[$($appMApp.TestData.testingTimeTakenString).Count-1]
                        },
                        @{
                            name = "AppM - Test Start Time"
                            value = $($appMApp.TestData.testingStart)[$($appMApp.TestData.testingStart).Count-1]
                        },
                        @{

                            name = "AppM - Old Test Data"
                            value = "$oldTestDataString"
                        }
                    )
                }             
            } else {
                $json = @{
                    customFieldValues = @(
                        @{
                            name = "AppM - App Manufacturer"
                            value = "$($appMApp.basic.manufacturer)"
                        },
                        @{
                            name = "AppM - App Name"
                            value = "$($appMApp.basic.name)"
                        },
                        @{
                            name = "AppM - App Version"
                            value = "$($appMApp.basic.packageVersion)"
                        }
                    )
                }
            }
            Set-JuribaImportApplication -Instance $dwInstance -APIKey $dwToken -UniqueIdentifier $appMApp.originalApplicationId -ImportId $($feed.id) -JsonBody ($json | ConvertTo-Json)
        }
    }
}


Write-Host 'Running a transform only ETL job...'
$transformEtl = Get-JuribaETLJob -Instance $dwInstance -APIKey $dwToken -Name "Dashworks ETL (Transform Only)"
if ($transformEtl.status -eq "Idle") {
    Start-JuribaETLJob -Instance $dwInstance -APIKey $dwToken -JobId $transformEtl.id
    while ($True) {
        Start-Sleep -Seconds 5
        try
        {
            $transformEtl = Get-JuribaETLJob -Instance $dwInstance -APIKey $dwToken -Name "Dashworks ETL (Transform Only)"
            if ($transformEtl.status -eq "Idle") {
                Write-Host "Transform ETL job complete."
                break
            } elseif ($transformEtl.status -eq "Executing") {
                Write-Host "Transform ETL executing..."
            }
        }
        catch
        {
            Write-Error "Unable to get Transform ETL job status..."
        }
    }
} else {
    Write-Error "Transform ETL Job currently not in idle state..."
}