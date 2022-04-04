SET NOCOUNT OFF

IF OBJECT_ID('tempdb..#Computers') IS NOT NULL DROP TABLE #Computers

CREATE TABLE #Computers(
	[uniqueIdentifier] [nvarchar](256) NOT NULL,
	[chassisType] [nvarchar](50) NULL)

/* Get active devices from SCCM, adjust as required 
   Using views v_R_System or v_R_System_Valid could work here too
   Table is used for performance
*/
INSERT INTO #Computers
	([UniqueIdentifier])
SELECT 
	ItemKey 
FROM System_DISC
WHERE ISNULL(Obsolete0,0) != 1 
	AND ISNULL(Decommissioned0,0) != 1 
	AND ISNULL(Active0,1) = 1
	--AND Client0 = 1 

-- Get chassis type
UPDATE C 
SET chassisType 	= 	LEFT(L.ChassisDescription, 50)
FROM #Computers C 
JOIN System_Enclosure_DATA SED 
	ON SED.MachineID = C.UniqueIdentifier
JOIN DesktopBI.dbo.LkpChassisTypes L
	ON L.ChassisTypeID = SED.ChassisTypes00
	--AND SED.ChassisTypes00 NOT IN (12,21)

SELECT * FROM #Computers