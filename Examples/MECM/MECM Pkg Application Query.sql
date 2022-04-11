SELECT DISTINCT 
	pkg.Name AS [Name], 
	pkg.Manufacturer as [Manufacturer],
	pkg.Version as [Version],
    pkg.PackageID + adv.ProgramName as [UniqueIdentifier]
FROM v_Advertisement adv 
JOIN v_Package pkg ON adv.PackageID = pkg.PackageID 
