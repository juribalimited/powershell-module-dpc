<#
    .SYNOPSIS
    Store server details and credentials in a data table for use in
	importing devices From ServiceNow into a Dashworks Device Feed.

    .DESCRIPTION
    Creates a database of the name given in the same path as the script.
	Stores the gioven credentials in a datatable created for that purpose.
#>

$DLLPath = "$PSScriptRoot\System.Data.SQLite.dll"
$DBPath = "$PSScriptRoot\DWCSN.db"

#ServiceNow Configuration Settings
$ServiceNow_ServerURL = 'https://XXXX.service-now.com'
$ServiceNow_Username = 'XXXX'
$ServiceNow_Password = 'XXXXXXXXXXXXXXXX'
$ServiceNow_AuthType = 'OAuth'
$ServiceNow_ClientId = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXX'
$ServiceNow_ClientSecret = 'XXXXXXXX'

#Dashworks Configuration Settings
$Dashworks_ServerURL = 'https://XXXX.dashworks.app:8443'
$Dashworks_APIKey = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'


if ($ServiceNow_AuthType -eq 'OAuth')
{
    $ServiceNow_AuthID='101'   
}elseif ($ServiceNow_AuthType -eq 'Basic')
{
    $ServiceNow_AuthID='102'
}

Add-Type -Path $DLLPath

#Creates a connection to a database. If the file doesn't exist, it will be created in the local directory.
$con = New-Object -TypeName System.Data.SQLite.SQLiteConnection
$con.ConnectionString = "Data Source=$DBPath"
$con.Open()

$sql = $con.CreateCommand()
$sql.CommandText = '
CREATE TABLE "APICredentials" (
	"DistHierID"	INTEGER,
	"FriendlyName"	TEXT,
	"Server"	TEXT,
	"Username"	TEXT,
	"Password"	TEXT,
	"AuthType"	INTEGER,
	"ClientId"	TEXT,
	"ClientSecret"	TEXT,
	"RefreshToken"	TEXT,
	"RefreshTokenExpires"	TEXT,
	"AccessToken"	TEXT,
	"AccessTokenExpires"	TEXT,
	"SyncTable"	TEXT,
	PRIMARY KEY("DistHierID")
)'

$sql.ExecuteNonQuery()

$sql.CommandText = "
INSERT INTO APICredentials
(DistHierID,FriendlyName,Server,Username,Password,AuthType,ClientId,ClientSecret,SyncTable)
VALUES
(1,'Dashworks','$Dashworks_ServerURL','','$Dashworks_APIKey','','','',''),
(2,'ServiceNow','$ServiceNow_ServerURL','$ServiceNow_Username','$ServiceNow_Password','$ServiceNow_AuthID','$ServiceNow_ClientId','$ServiceNow_ClientSecret','$ServiceNow_SyncTable')
"

$sql.ExecuteNonQuery()

$con.Close()