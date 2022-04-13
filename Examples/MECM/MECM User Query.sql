
SELECT [User_Name0] Username
      ,[Full_User_Name0] [DisplayName]
      ,[SID0] [ObjectSid]
      ,[Object_GUID0] [ObjectGuid]
      ,CASE WHEN [User_Account_Control0] & 2=2 THEN 1 ELSE 0 END [Disabled]
	,CASE WHEN CHARINDEX(' ',REVERSE([Full_User_Name0]),0)>0 THEN RIGHT([Full_User_Name0],CHARINDEX(' ',REVERSE([Full_User_Name0]),0)-1) ELSE [Full_User_Name0] END [Surname]
	,RTRIM(REPLACE([Full_User_Name0],CASE WHEN CHARINDEX(' ',REVERSE([Full_User_Name0]),0)>0 THEN RIGHT([Full_User_Name0],CHARINDEX(' ',REVERSE([Full_User_Name0]),0)-1) ELSE [Full_User_Name0] END,'')) [GivenName]
      ,[Mail0] [EmailAddress]
      ,[User_Principal_Name0] [UserPrincipalName]
FROM [User_DISC]