#Requires -Version 7

$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

function Update-ApplicationOwner {
    <#
		.SYNOPSIS
		Export DPC applications.
		.DESCRIPTION
		Export applications and users from DPC for use in Application Owner.
		.PARAMETER DpcInstance
		DPC instance. For example, https://myinstance.dashworks.app:8443
		.PARAMETER DpcApiKey
		DPC API Key.
		.PARAMETER AoInstance
		AOM instance. For example, https://myinstance.juriba.app
		.PARAMETER AoApiKey
		AOM API Key.
        .PARAMETER InputBatchLength
        The maximum number of records returned in a single call to DPC.
        .PARAMETER InputBatchStartOffset
        The offset within the initial batch to start from, can be used to skip previously processed data.
        .PARAMETER MaximumAppsToImport
        The maximum number of applications to process, or 0 for all.
        .PARAMETER OutputBatchLength
        The maximum number of records sent in a single call to AOM.
		.EXAMPLE
		PS> Update-ApplicationOwner https://myinstance.dashworks.app:8443 pCyty***** https://myinstance.juriba.app hoF7k*****
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DpcInstance,
        [Parameter(Mandatory=$true)]
        [string]$DpcApiKey,
        [Parameter(Mandatory=$true)]
        [string]$AoApiKey,
        [Parameter(Mandatory=$false)]
        [string]$AoInstance = "https://ao.juriba.com",
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 10000)]
        [int]$InputBatchLength = 10000,
        [Parameter(Mandatory=$false)]
        [ValidateScript({
            if ($_ -ge 0) {
                $true
            } else {
                throw "Value must be greater than or equal to 0."
            }
        })]
        [int]$InputBatchStartOffset = 0,
        [Parameter(Mandatory=$false)]
        [ValidateScript({
            if ($_ -ge 0) {
                $true
            } else {
                throw "Value must be greater than or equal to 0."
            }
        })]
        [int]$MaximumAppsToImport = 0,
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 10000)]
        [int]$OutputBatchLength = 10000
    )

    $me = Invoke-RestMethod -Method Get -Uri "$AoInstance/api/me" -Headers @{'x-api-key' = $AoApiKey}
    if ($me.tenants.Count -ne 1) {
        throw "Expected 1 tenant, found $($me.tenants.Count)."
    }
    $tenantId = $me.tenants[0].id

    $subscription = Invoke-RestMethod -Method Get -Uri "$AoInstance/api/tenant/$tenantId/subscription" -Headers @{'x-api-key' = $AoApiKey}
    if ($null -eq $subscription.type) {
        throw "Unable to obtain subscription details for tenant $tenantId."
    }
    $userLimit = 0
    if ($subscription.type -eq "Trial") {
        $userLimit = $subscription.usersQuota.total ? $subscription.usersQuota.total : 100
        $inUse = $subscription.usersQuota.used ? $subscription.usersQuota.used : 0
        Write-Information "Trial is limited to $userLimit users, with $inUse already in use."
    }

    $tenancyDetails = Invoke-RestMethod -Method Get -Uri "$AoInstance/api/tenant/$tenantId" -Headers @{'x-api-key' = $AoApiKey}
    if ($null -eq $tenancyDetails.checkInIntervalInDays) {
        throw "Unable to obtain tenancy details for tenant $tenantId."
    }

    # Initialize an empty array to store the results
    $results = @()

    # Loop until no more data is returned from the REST call or the limit is reached
    do {
        $BatchLength = $InputBatchLength
        Write-Information "Fetching next $BatchLength records from DPC, starting from $InputBatchStartOffset"
        # Build the URI with the dynamic parameters
        $uri = "$DpcInstance/apiv1/applications?`$top=$BatchLength&`$skip=$InputBatchStartOffset&`$select=packageName,packageManufacturer,packageVersion,ownerEMailAddress,ownerDisplayName,ownerDistinguishedName,ownerCommonName"

        # Invoke the curl command to get the JSON response
        $jsonResponse = Invoke-RestMethod -Method Get -Uri $uri -Headers @{
            'X-Api-Key' = $DpcApiKey
        }
        # Append the results defined in the JSON to the existing results array
        $jsonResponse.results | ForEach-Object {
            # Perform the projection here
            # Example: Select specific properties from the JSON response
            if ($MaximumAppsToImport -ne 0 -and $results.Count -ge $MaximumAppsToImport) {
                break
            }
            elseif (![string]::IsNullOrEmpty($_.packageName)) {
                $results += [PSCustomObject]@{
                    packageName = $_.packageName
                    packageManufacturer = if ($_.packageManufacturer) { $_.packageManufacturer } else { "Unknown" }
                    packageVersion = if ($_.packageVersion) { $_.packageVersion } else { "Unknown" }
                    ownerEMailAddress = $_.ownerEMailAddress
                    ownerDisplayName = $_.ownerDisplayName
                    ownerDistinguishedName = $_.ownerDistinguishedName
                    ownerCommonName = $_.ownerCommonName
                }
            }
        }

        # Increment the InputBatchStartOffset by BatchLength for the next iteration
        $InputBatchStartOffset += $BatchLength
    } while ($jsonResponse.results -and ($MaximumAppsToImport -eq 0 -or $results.Count -lt $MaximumAppsToImport))

    if ($results.Count -gt 0) {
        # Group the results by packageName
        [array]$groupedResults = $results | Group-Object -Property packageName

        Write-Information "Fetched $($results.Count) results with $($groupedResults.Count) unique packages."

        # Access the required properties from the grouped results
        foreach ($group in $groupedResults) {
            $packageName = $group.Name
            $groupedApps = $group.Group
            [array]$uniqueManufacturers = $groupedApps | Select-Object -ExpandProperty packageManufacturer -Unique
            $manufacturerCount = $uniqueManufacturers.Count
            if ($manufacturerCount -gt 1) {
                Write-Debug "More than one manufacturer found for package $packageName."
            }
        }

        # create JSON for import to aom using /api/tenant/{tenantId}/application/bulk-import
        $aomData = @()
        $users = @{}
        foreach ($group in $groupedResults) {
            $packageName = $group.Name
            [array]$allVersions = $group.Group | Select-Object -ExpandProperty packageVersion -Unique | Where-Object { $_ -ne "Unknown" } | Sort-Object -Descending
            if ($null -eq $allVersions) {
                $highestVersion = "Unknown"
            } else {
                $highestVersion = $allVersions[0]
            }
            if ($users.ContainsKey($group.Group[0].ownerEMailAddress)) {
                $users.Add($group.Group[0].ownerEMailAddress, $group.Group[0].ownerDisplayName)
            }
            
            $aomData += [PSCustomObject]@{
                name = $group.Name
                manufacturer = $group.Group[0].packageManufacturer
                currentVersion = $highestVersion
                ownerEmail = $group.Group[0].ownerEMailAddress
                ownerName = $group.Group[0].ownerDisplayName
                ownerNotRequired = $false
                checkInInterval = "$($tenancyDetails.checkInIntervalInDays)"
            }
        }

        $OutputBatchOffset = 0
        $Failed = $false
        do {
            $headers = @{
                'x-api-key' = $AoApiKey
                'Content-Type' = 'application/json'
            }
            try {
                [array]$batch = $aomData | Select-Object -Skip $OutputBatchOffset -First $OutputBatchLength
                Write-Information "Uploading packages $($OutputBatchOffset + 1) to $($OutputBatchOffset + $batch.Count) of $($aomData.Count)"
                $response = Invoke-RestMethod -Method Post -Uri "$AoInstance/api/tenant/$tenantId/application/bulk-import" -Body (@{ "applications" = $batch } | ConvertTo-Json -Depth 5) -Headers $headers    
                Write-Information "  Status: $($response.imported) packages, $($response.failed) failed."
                $OutputBatchOffset += $OutputBatchLength
            }
            catch {
                $response = $_ | ConvertFrom-Json -AsHashtable
                Write-Warning $response.title
                if ($null -ne $response['detail']) {
                    Write-Warning "  $($response['detail'])."
                }
                Write-Warning "There were $($response.errors.Keys.Count) errors."
                foreach ($Key in $response["errors"].Keys) {
                    foreach ($item in $response["errors"][$Key]) {
                        Write-Error -Message $item["message"] -ErrorAction Continue
                    }
                }
                $Failed = $true
            }
        } while (!$Failed -and $OutputBatchOffset -lt $aomData.Count);

        if (!$Failed) {
            Write-Information "Upload complete"
        } else {
            Write-Information "Upload FAILED"
        }
    }  else {
        Write-Information "No data found in DPC.  Upload terminated."
    }
}
