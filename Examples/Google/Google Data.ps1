Install-Module Configuration
Install-Module -Name PSGSuite

$env:GOOGLE_APPLICATION_CREDENTIALS="C:\Users\andyyu.DWLABS\Desktop\Google\centering-seer-412217-f30b645af45a.p12"

#Declare variables
$ConfigName = "GSuite"
$P12KeyPath = $env:GOOGLE_APPLICATION_CREDENTIALS
$AppEmail = "noeytestapi@centering-seer-412217.iam.gserviceaccount.com"
$AdminEmail = "andy@noeypurdie.co.uk"
$CustomerID = "C02soo0u5"
$Domain = "noeypurdie.co.uk"
$ServiceAccountClientID = "110011754200761142135"

Set-PSGSuiteConfig -ConfigName $ConfigName `
-P12KeyPath $P12KeyPath -AppEmail $AppEmail `
-AdminEmail $AdminEmail -CustomerID $CustomerID `
-Domain $Domain  -ServiceAccountClientID $ServiceAccountClientID

#Get groups
$groups = Get-GSGroup | Where-Object {$_.AdminCreated -eq $True}

$GroupMembers = $null

#Get members from each group
#Fields required
#Name
#Kind
#Email
foreach($group in $groups) {
    $groupName = $group.Name
    $groupKind = $group.Kind
    $GroupMembers += Get-GSGroupMember $group.Email | Select-Object @{ n = "GroupName"; e = { $groupName }}, @{ n = "GroupKind"; e = { $groupKind }}, Email
}


$users = Get-GSUserList
$user = $users | Where-Object {$_.User -eq "andy@noeypurdie.co.uk"}
$users[1].Emails
$users[1].ExternalIds
$users[1].Relations
$users[1].Kind
#Fields to extract
#User (Email address)
#Id
#LastLoginTimeRaw
#Locations
#OrgUnitPath
#Phones

#Get Organizational Unit
$orgunits = Get-GSOrganizationalUnitList

#Get members from each organizational unit
foreach($orgunit in $orgunits) {
    Get-GSGroupMember $orgunit.Email | Format-Table
}
#Fields required
#OrgUnitId
#OrgUnitPath
#Name
#ParentOrgUnitId
#ParentOrgUnitPath




$group.count
$grouplist.count

Get-GSMobileDeviceList

#$env:GOOGLE_APPLICATION_CREDENTIALS="C:\Users\Andy\OneDrive - Juriba\Work\Cabinet Office\Google feed\centering-seer-412217-f30b645af45a.p12"

$Users = Get-GSUserList 

foreach ($User in $Users) { 

    $user | Select User,

    @{N="FamilyName" ; E={($_.Name.familyname)}},

    @{N="GivenName" ; E={($_.Name.GivenName)}}, PrimaryEmail | Export-Csv C:\Users\Andy\Documents\UserList.csv -NoTypeInformation -Append

} 