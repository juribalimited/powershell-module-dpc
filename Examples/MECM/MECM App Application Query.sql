SELECT 
	[Name], 
	[Manufacturer], 
	[Version], 
	PackageID AS [UniqueIdentifier]
FROM v_Package   
WHERE PackageType = 8