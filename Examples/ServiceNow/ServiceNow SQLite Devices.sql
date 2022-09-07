SELECT C.sys_id AS uniqueIdentifier
	,C.name AS Hostname
	,C.os AS operatingSystemName
	,nullif(C.os_version,'') AS operatingSystemVersion
	,nullif(C.os_service_pack,'') AS operatingSystemServicePack
	,CC.name AS computerManufacturer
	,CM.name AS computerModel	
	,C.form_factor AS chassisType
	,C."virtual" AS virtualMachine
	,C.purchase_date AS purchaseDate
	,C.serial_number AS serialNumber
	,C.cpu_count AS processorCount
	,nullif(C.cpu_speed,'') AS processorSpeed
	,nullif(C.cpu_type,'') AS processorManufacturer
	,CASE WHEN C.disk_space > 0 THEN CAST(C.disk_space*1024 AS INTEGER) END AS totalHDDSpaceMb
	,CASE WHEN C.ram > 0 THEN CAST(C.ram*1024 AS INTEGER) END AS memoryMB
	,asset_tag assetTag
	/*,U.email*/
FROM SN_cmdb_ci_computer C
LEFT JOIN SN_sys_user U ON C.assigned_to=U.sys_id
LEFT JOIN SN_core_company CC ON C.manufacturer=CC.sys_id
LEFT JOIN SN_cmdb_model CM ON C.model_id=CM.sys_id