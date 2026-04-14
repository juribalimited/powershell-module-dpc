function Get-EntraIdGroupMembershipTable {
<#
.SYNOPSIS
Builds a Juriba-ready group membership mapping table from Entra ID groups.

.DESCRIPTION
Constructs a System.Data.DataTable representing group-to-member
relationships for Entra ID groups.

For each group supplied, the function retrieves group membership data
from Microsoft Entra ID using Get-EntraIdGroupMember and transforms the
results into a flattened relationship table suitable for importing
group membership data into Juriba.

The resulting table contains one row per group-member relationship and
includes Juriba-specific metadata such as import identifiers and object
type classification.

.PARAMETER AccessToken
A valid OAuth 2.0 bearer token for Microsoft Graph with permission to
read Entra ID group membership data.

.PARAMETER Groups
An array of group objects containing a `uniqueIdentifier` property.
These are typically obtained from a prior Entra ID group import or
transformation step.

.PARAMETER ImportId
A unique identifier representing the current data import operation.
This value is added to all rows to associate records with a specific
Juriba import.

.OUTPUTS
System.Data.DataTable

Returns a DataTable representing Entra ID group membership relationships
with the following columns:

- groupUniqueIdentifier
- memberUniqueIdentifier
- importId
- objectType
- isPrimary

.EXAMPLE
$membershipTable = Get-EntraIdGroupMembershipTable `
    -AccessToken $AccessToken `
    -Groups $Groups `
    -ImportId $ImportId

Generates a Juriba-compatible group membership table for the supplied
groups.

.EXAMPLE
$groups = Get-EntraIdGroup -AccessToken $AccessToken
$membershipTable = Get-EntraIdGroupMembershipTable `
    -AccessToken $AccessToken `
    -Groups $groups `
    -ImportId ImportId

Retrieves Entra ID groups and builds a group membership mapping table.

.NOTES
- Uses Get-EntraIdGroupMember to retrieve group membership
- Group members may include users, devices, or other directory objects
- Device members use deviceId as the memberUniqueIdentifier
- Intended for use as a preprocessing step before importing group
  membership data into Juriba
#>
    [CmdletBinding()]
    [OutputType([System.Data.DataTable])]
    param (
        [Parameter(Mandatory)]
        [string]$AccessToken,
        [Parameter(Mandatory)]
        [array]$Groups,
        [Parameter(Mandatory)]
        [string]$ImportId
    )

    # Build output DataTable
    $groupMemberTable = New-Object System.Data.DataTable
    $groupMemberTable.Columns.Add("groupUniqueIdentifier", [string]) | Out-Null
    $groupMemberTable.Columns.Add("memberUniqueIdentifier", [string]) | Out-Null
    $groupMemberTable.Columns.Add("importId", [string]) | Out-Null
    $groupMemberTable.Columns.Add("objectType", [string]) | Out-Null
    $groupMemberTable.Columns.Add("isPrimary", [boolean]) | Out-Null

    foreach ($group in $Groups) {

        $groupId = $group.uniqueIdentifier

        # Pull group members from Entra ID
        $groupMembers = Get-EntraIdGroupMember `
                        -AccessToken $AccessToken `
                        -GroupId $groupId |
                       Select-Object id, '@odata.type', deviceId

        foreach ($member in $groupMembers) {
            $objectType = ($member.'@odata.type').Split('.')[-1]
            $row = $groupMemberTable.NewRow()
            $row.groupUniqueIdentifier = $groupId
            $row.memberUniqueIdentifier = if ($objectType -eq "device") {$member.deviceId} else {$member.id}
            $row.importId  = $ImportId
            $row.objectType = ($member.'@odata.type').Split('.')[-1]
            $row.isPrimary = if ($objectType -eq "device") {1} else {0}

            $groupMemberTable.Rows.Add($row)
        }
    }

    $PSCmdlet.WriteObject($groupMemberTable, $false)
}