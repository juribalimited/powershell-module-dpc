SELECT DISTINCT 
	pkg.Name AS [Name], 
	pkg.Manufacturer as [Manufacturer],
	pkg.Version as [Version],
    pkg.PackageID + adv.ProgramName as [UniqueIdentifier]
FROM v_Advertisement adv 
JOIN v_Package pkg ON adv.PackageID = pkg.PackageID 
--JOIN v_ClientAdvertisementStatus stat ON stat.AdvertisementID = adv.AdvertisementID 
--JOIN v_R_System sys ON stat.ResourceID=sys.ResourceID 

/*
SELECT  
	sys.ResourceId,
	adv.AdvertisementName, 
	stat.LastStateName, 
	adv.Comment AS [Comment],  
	pkg.Name AS [PackageName], 
	pkg.Manufacturer as [PackageManufacturer],
	pkg.Version as [PackageVersion],
	adv.ProgramName AS [ProgramName], 
	adv.SourceSite, 
	adv.AdvertisementID,
    adv.PackageID,
    adv.CollectionID,
    pkg.PackageID + adv.ProgramName as PackageProgramID
FROM v_Advertisement adv 
JOIN v_Package pkg ON adv.PackageID = pkg.PackageID 
JOIN v_ClientAdvertisementStatus stat ON stat.AdvertisementID = adv.AdvertisementID 
JOIN v_R_System sys ON stat.ResourceID=sys.ResourceID 
*/