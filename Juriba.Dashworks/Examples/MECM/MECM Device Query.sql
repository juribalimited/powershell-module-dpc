SET NOCOUNT OFF

IF OBJECT_ID('tempdb..#Computers') IS NOT NULL DROP TABLE #Computers

CREATE TABLE #Computers(
	[uniqueIdentifier] [nvarchar](256) NOT NULL,
	[hostname] [nvarchar](100) NULL,
	[site] [nvarchar](50) NULL,
	[ownerDomain] [nvarchar](256) NULL,
	[ownerUsername] [nvarchar](100) NULL,
	[computerDomain] [nvarchar](256) NULL,
	[operatingSystemName] [nvarchar](128) NULL,
	[operatingSystemVersion] [nvarchar](20) NULL,
	[operatingSystemArchitecture] [nvarchar](10) NULL,
	[operatingSystemServicePack] [nvarchar](50) NULL,
	[computerManufacturer] [nvarchar](50) NULL,
	[computerModel] [nvarchar](50) NULL,
	[chassisType] [nvarchar](50) NULL,
	[virtualMachine] [nvarchar](10) NULL ,
	[purchaseDate] [datetime] NULL,
	[firstSeenDate] [datetime] NULL,
	[lastSeenDate] [datetime] NULL,
	[buildDate] [datetime] NULL,
	[bootupDate] [datetime] NULL,
	[serialNumber] [nvarchar](100) NULL,
	[processorCount] [int] NULL,
	[processorManufacturer] [nvarchar](50) NULL,
	[processorModel] [nvarchar](128) NULL,
	[processorSpeed] [int] NULL,
	[processor64Bit] [smallint] NULL,
	[memoryKb] [int] NULL,
	[networkCardDescription] [nvarchar](100) NULL,
	[iPv4Address] [nvarchar](64) NULL,
	[iPv4SubnetMask] [nvarchar](64) NULL,
	[iPv6Address] [nvarchar](64) NULL,
	[iPv6SubnetMask] [int] NULL,
	[macAddress] [nvarchar](64) NULL,
	[videoCardCount] [int] NULL,
	[videoCardManufacturer] [nvarchar](100) NULL,
	[videoCardModel] [nvarchar](100) NULL,
	[soundCardCount] [int] NULL,
	[soundCardManufacturer] [nvarchar](100) NULL,
	[soundCardModel] [nvarchar](100) NULL,
	[hDDCount] [int] NULL,
	[totalHDDSpaceMb] [int] NULL,
	[targetDriveFreeSpaceMb] [int] NULL,
	[bIOSManufacturer] [nvarchar](256) NULL,
	[bIOSName] [nvarchar](100) NULL,
	[bIOSVersion] [nvarchar](50) NULL,
	[monitorCount] [int] NULL,
	[monitorManufacturer] [nvarchar](100) NULL,
	[monitorModel] [nvarchar](256) NULL,
	[monitorScreenHeight] [int] NULL,
	[monitorScreenWidth] [int] NULL,
	[tpmEnabled] [int] NULL, 
	[tpmVersion] [nvarchar](10) NULL,
	[secureBootEnabled] [int] NULL)

/* Get active devices from SCCM, adjust as required 
   Using views v_R_System or v_R_System_Valid could work here too
   Table is used for performance
*/
INSERT INTO #Computers
	([UniqueIdentifier], Hostname)
SELECT 
	ItemKey 
	, LEFT(Name0, 100) 
FROM System_DISC
WHERE ISNULL(Obsolete0,0) != 1 
	AND ISNULL(Decommissioned0,0) != 1 
	AND ISNULL(Active0,1) = 1
	AND Client0 = 1 

-- Get SiteCode
UPDATE C 
SET Site = S.SiteCode
FROM #Computers C 
JOIN Sites S 
    ON S.SiteKey = 1

-- Get additional info from System
UPDATE C 
SET  ownerDomain    =   LEFT(SD.User_Domain0, 256)
	,ownerUsername 	=  	LEFT(SD.User_Name0, 100)
	,computerDomain = 	LEFT(SD.Resource_Domain_OR_Workgr0, 256)
    ,firstSeenDate 	=  	SD.Creation_Date0
FROM #Computers C 
JOIN System_DISC SD 
    ON SD.ItemKey = C.UniqueIdentifier

-- Get OS 
UPDATE C 
SET  operatingSystemName 			= LEFT(OSD.Caption00, 128)
    ,operatingSystemVersion 		= LEFT(OSD.Version00, 20)
    ,operatingSystemServicePack 	= LEFT(COALESCE(WSLN.Value, OSD.CSDVersion00), 50)
    ,buildDate 						= OSD.InstallDate00
	,bootupDate 					= OSD.LastBootUpTime00
FROM #Computers C 
JOIN System_DISC SD 
    ON SD.ItemKey = C.UniqueIdentifier
JOIN Operating_System_DATA OSD 
	ON SD.ItemKey = OSD.MachineID 
	AND NOT (OSD.Caption00 IS NULL AND OSD.Version00 IS NULL AND OSD.CSDVersion00 IS NULL)
LEFT JOIN fn_GetWindowsServicingStates() WSS
    ON WSS.Build = OSD.Version00
	AND WSS.Branch = SD.OSBranch01
LEFT JOIN fn_GetWindowsServicingLocalizedNames() WSLN
    ON WSS.Name = WSLN.Name

-- Get manufacturer and model
UPDATE C 
SET computerManufacturer 	= LEFT(CSD.Manufacturer00, 50)
	,computerModel 			= LEFT(CSD.Model00, 50)
    ,virtualMachine 		= 	CASE 
									WHEN SD.Is_Virtual_Machine0 = 1 THEN '1'
									WHEN CSD.Model00 = 'Virtual Machine' THEN '1' 
									WHEN CSD.Model00 = 'VMware Virtual Platform' THEN '1' 
									WHEN CSD.Model00 = 'VirtualBox' THEN '1' 
									WHEN CSD.Manufacturer00 = 'Amazon EC2' THEN '1'
									WHEN CSD.Manufacturer00 = 'Xen' THEN '1'
									ELSE '0' 
	 							END
FROM #Computers C 
JOIN System_DISC SD 
    ON SD.ItemKey = C.UniqueIdentifier
JOIN Computer_System_DATA CSD 
	ON CSD.MachineID = SD.ItemKey

-- Get chassis type
UPDATE C 
SET chassisType 	= 	LEFT(SED.ChassisTypes00, 50)
FROM #Computers C 
JOIN System_Enclosure_DATA SED 
	ON SED.MachineID = C.UniqueIdentifier
	--AND SED.ChassisTypes00 NOT IN (12,21)

-- Get last seen date
UPDATE C 
SET lastSeenDate = WSD.LastHWScan
FROM #Computers C 
JOIN WorkstationStatus_DATA WSD 
	ON WSD.MachineID = C.UniqueIdentifier

-- Get serial number and bios info
UPDATE C 
SET  serialNumber 		= LEFT(PBD.SerialNumber00, 100)
    ,bIOSManufacturer 	= LEFT(PBD.Manufacturer00, 256)
	,bIOSName 			= LEFT(PBD.Name00, 100)
	,bIOSVersion 		= LEFT(PBD.Version00, 50)
FROM #Computers C 
JOIN PC_BIOS_DATA PBD 
	ON PBD.MachineID = C.UniqueIdentifier

-- Get cpu info
UPDATE C 
SET  operatingSystemArchitecture 	= 	LEFT(PD.AddressWidth00, 10)
    ,processorCount 				= 	1
	,processorManufacturer 			= 	LEFT(PD.Manufacturer00, 50)
	,processorModel 				= 	LEFT(PD.Name00, 128)
	,processorSpeed 				= 	COALESCE(PD.CurrentClockSpeed00, PD.MaxClockSpeed00)
	,processor64Bit 				= 	CASE WHEN PD.DataWidth00 = 64 THEN 1 ELSE 0 END
FROM #Computers C 
JOIN Processor_DATA PD 
	ON PD.MachineID = C.UniqueIdentifier

-- Get memory info
UPDATE C 
SET memoryKb = PMD.TotalPhysicalMemory00
FROM #Computers C 
JOIN PC_Memory_DATA PMD 
	ON PMD.MachineID = C.UniqueIdentifier

-- Get network info
UPDATE C 
SET networkCardDescription 	= LEFT(NCD.ProductName00, 100)
    ,iPv4Address 			= LEFT(NWD.IPAddress00, 64)
	,iPv4SubnetMask 		= NWD.IPSubnet00
	,iPv6Address 			= NULL 
	,iPv6SubnetMask 		= NULL  
	,mACAddress 			= LEFT(NWD.MACAddress00, 64)
FROM #Computers C 
JOIN Netcard_DATA NCD 
	ON NCD.MachineID = C.UniqueIdentifier
JOIN Network_DATA NWD 
	ON NWD.MachineID = C.UniqueIdentifier
	AND NWD.Index00 = NCD.DeviceID00 
	AND NWD.IPAddress00 IS NOT NULL 
	AND NWD.MACAddress00 IS NOT NULL 
	AND NWD.IPAddress00 != '0.0.0.0'

-- Get video card info
UPDATE C 
SET  videoCardCount 		= 1
	,videoCardManufacturer 	= LEFT(VCD.Description00, 100)
	,videoCardModel 		= LEFT(VCD.Name00, 100)
FROM #Computers C 
JOIN Video_Controller_DATA VCD 
	ON VCD.MachineID = C.UniqueIdentifier
	AND NOT (VCD.AdapterCompatibility00 IS NULL AND VCD.Name00 IS NULL)

-- Get sound card info
UPDATE C 
SET  soundCardCount 			= 1
	,soundCardManufacturer 		= LEFT(SDD.Manufacturer00, 100)
	,soundCardModel 			= LEFT(SDD.Name00, 100)
FROM #Computers C 
JOIN Sound_Devices_DATA SDD 
	ON SDD.MachineID = C.UniqueIdentifier

-- Get disk info
UPDATE C 
SET  hDDCount 				= 1
	,totalHDDSpaceMb		= LDD.Size00
	,targetDriveFreeSpaceMb = LDD.FreeSpace00
FROM #Computers C 
JOIN Logical_Disk_DATA LDD 
	ON LDD.MachineID = C.UniqueIdentifier
	AND LDD.DeviceID00 = 'C:'

-- Get monitor info
UPDATE C 
SET  monitorCount 			= 1
	,monitorManufacturer 	= LEFT(DMD.MonitorManufacturer00, 100)
	,monitorModel 			= LEFT(DMD.Name00, 256)
	,monitorScreenHeight 	= DMD.ScreenHeight00
	,monitorScreenWidth 	= DMD.ScreenWidth00
FROM #Computers C 
JOIN Desktop_Monitor_DATA DMD 
	ON DMD.MachineID = C.UniqueIdentifier

-- Get tpm info
UPDATE C 
SET  tpmEnabled = TPM.IsEnabled_InitialValue00
	,tpmVersion = LEFT(TPM.SpecVersion00, 10)
FROM #Computers C 
JOIN TPM_DATA TPM
	ON TPM.MachineId = C.UniqueIdentifier

-- Get firmware info
UPDATE C 
SET secureBootEnabled = FW.SecureBoot00
FROM #Computers C 
JOIN Firmware_DATA FW
	ON FW.MachineId = C.UniqueIdentifier

SELECT * FROM #Computers