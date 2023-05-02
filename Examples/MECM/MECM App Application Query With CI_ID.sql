SELECT 
    [Name], 
    [Manufacturer], 
    [Version], 
    PackageID,
    CONVERT(varchar(10), CP.CI_ID) AS [UniqueIdentifier],
    CI.CI_UniqueID
FROM v_Package P
JOIN CIContentPackage CP ON CP.PkgId = P.PackageID
JOIN CI_ConfigurationItems CI ON CP.CI_ID = CI.CI_ID
WHERE PackageType = 8