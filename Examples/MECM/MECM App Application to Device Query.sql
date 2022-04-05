SELECT 
	sd.ResourceID as DeviceUniqueIdentifier,
	ds.PackageID as ApplicationUniqueIdentifier
FROM v_R_System_Valid sd
INNER JOIN v_FullCollectionMembership cm ON cm.ResourceID = sd.ResourceID
INNER JOIN v_DeploymentSummary ds ON ds.CollectionID = cm.CollectionID AND ds.FeatureType = 1
