SELECT DISTINCT 
	sys.ResourceId AS [DeviceUniqueIdentifier],
    pkg.PackageID + adv.ProgramName as [ApplicationUniqueIdentifier]
FROM v_Advertisement adv 
JOIN v_Package pkg ON adv.PackageID = pkg.PackageID 
JOIN v_ClientAdvertisementStatus stat ON stat.AdvertisementID = adv.AdvertisementID 
JOIN v_R_System sys ON stat.ResourceID=sys.ResourceID 
