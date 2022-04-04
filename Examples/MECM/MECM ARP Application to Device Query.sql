SELECT 
    MachineId AS DeviceUniqueIdentifier,
	CAST(CAST(HASHBYTES('MD5',Publisher00 + DisplayName00 + Version00) AS UNIQUEIDENTIFIER) AS NVARCHAR(50)) AS ApplicationUniqueIdentifier 
FROM (
	SELECT 
		MachineId,
		ISNULL(DisplayName00, '') AS DisplayName00,
		ISNULL(Publisher00, '') AS Publisher00,
		ISNULL(Version00, '') AS Version00
	FROM dbo.Add_Remove_Programs_DATA 
	UNION 
	SELECT 
		MachineId,
		ISNULL(DisplayName00, '') AS DisplayName00,
		ISNULL(Publisher00, '') AS Publisher00,
		ISNULL(Version00, '') AS Version00
	FROM dbo.Add_Remove_Programs_64_DATA  
	) ARP