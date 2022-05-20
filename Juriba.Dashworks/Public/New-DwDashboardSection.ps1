Function New-DwDashboardSection {

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$APIKey,
        [Parameter(Mandatory=$true)]
        [int]$DashboardId,
        [Parameter(Mandatory=$false)]
        [int]$Width = 2
    )

    $request = @{
        Uri         = ($Instance + "/apiv1/dashboard/" + $DashboardId + "/section/")
        Method      = "Post"
        Body        = @{
            "width" = $Width
        } | ConvertTo-Json
        ContentType = "application/json"
        Headers     = @{
            'X-API-KEY' = $APIKey
        }
    }

    if ($PSCmdlet.ShouldProcess($DashboardId)) {
        $response = Invoke-RestMethod @request
        $response.sectionId
    }

}
