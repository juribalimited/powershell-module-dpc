SELECT DISTINCT LUH.SoftwarePropertiesHash,LUH.SoftwareID,LUH.IsDeleted
INTO #LU_SoftwareHash
FROM (SELECT SoftwarePropertiesHash00 FROM INSTALLED_SOFTWARE_DATA UNION SELECT SoftwarePropertiesHash00 FROM RecentlyUsedApps_DATA) ISD
INNER JOIN dbo.LU_SoftwareHash LUH ON LUH.SoftwarePropertiesHash = ISD.SoftwarePropertiesHash00
WHERE LUH.IsDeleted = 0

CREATE CLUSTERED INDEX IX_tmp_LU_SoftwareHash ON #LU_SoftwareHash(SoftwarePropertiesHash)


SELECT ISNULL(CAST(LUH.SoftwareID AS NVARCHAR(255)),CAST(CAST(CAST(HASHBYTES('MD5',RUA.CompanyName00+RUA.ProductName00+RUA.ProductVersion00) AS UNIQUEIDENTIFIER) AS NVARCHAR(36)) AS NVARCHAR(255))) ApplicationUniqueIdentifier
	,SD.ItemKey DeviceUniqueIdentifier
	--,CASE WHEN CHARINDEX('\', RUA.LastUserName00) > 0 THEN LEFT(RUA.LastUserName00,CHARINDEX('\', RUA.LastUserName00) - 1) END UserDomain
	--,CASE WHEN CHARINDEX('\', RUA.LastUserName00) > 0 THEN RIGHT(RUA.LastUserName00,LEN(RUA.LastUserName00) - CHARINDEX('\', RUA.LastUserName00)) END UserDomain

FROM dbo.RecentlyUsedApps_DATA RUA
INNER JOIN dbo.System_DISC SD ON SD.ItemKey=RUA.MachineID
LEFT JOIN #LU_SoftwareHash LUH ON LUH.SoftwarePropertiesHash = RUA.SoftwarePropertiesHash00
WHERE RUA.SoftwarePropertiesHash00<>''
AND SD.Active0=1


DROP TABLE #LU_SoftwareHash