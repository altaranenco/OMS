# About SQLtoOMSDataSender.ps1
This script (along with OMSDataCollector.ps1) is designed to send SQL select results to Microsoft OMS (Log Analytics).
**Attention**
Don’t forget to change the variables in the script !!!

# Prerequisites
To transfer the SQL query results to Microsoft OMS (Log Analytics) you need:
- Microsoft Log Analytics space
- script [SQLtoOMSDataSender.ps1](https://github.com/altaranenco/OMS/blob/master/LogAnalyticsScripts/SQLtoOMSDataSender.ps1) and [OMSDataCollector.ps1](https://github.com/altaranenco/OMS/blob/master/OMSDataCollector.ps1) must be located in the same folder, for example, C:\LogAnalyticsScript\
- Internet access to OMS\Log Analytics servers on port 443, from the server on which the PowerShell scripts will be run
- the manually created directory structure for work, more on that below

# Configure the script SQLtoOMSDataSender.ps1 before first use
## space ID and key
Log Analytics Workplace ID and key are set by variables: $ CustomerId and $ SharedKey in the header of SQLtoOMSDataSender.ps1 script

## SQL select and parameters
You should set your own parameters for connecting to SQL server and run SQL select
$Serverinstance - SQL server name
$Database - SQL DB name
you can set your username and password or use Windows  Autentification
$Username - username with SQL permissions 
$Password - password to connect to SQL

$Query - your SQL select statesment. For example:
$Query = "select sys.Name0 AS Computer,  sys.Operating_System_Name_and0 as OS, umr.UniqueUserName, usr.DisplayName0, usr.Full_Domain_Name0, usr.Mail0, usr.physicalDeliveryOfficeNam0, usr.User_Name0, umr.UniqueUserName, umr.MachineResourceID, umi.ConsoleMinutes, umi.LastLoginTime, umi.NumberOfLogins
from v_R_User usr
LEFT JOIN v_UserMachineRelationship umr  on usr.Unique_User_Name0 = umr.UniqueUserName
LEFT JOIN v_R_System sys ON sys.ResourceID =umr.MachineResourceID
LEFT JOIN v_UserMachineIntelligence umi ON umr.MachineResourceID = umi.MachineResourceID
WHERE sys.Operating_System_Name_and0 NOT LIKE '%Server%'
order by Computer"

## directory structure
For the script to work correctly, you must ** manually ** create a directory structure:
**C:\LogAnalyticsScripts** - the root directory of the script. The SQLtoOMSDataSender.ps1 and OMSDataCollector.ps1 files should be located in the root. If you use another directory, not C:\LogAnalyticsScripts, do not forget to change the value of the variable $ RootFolder = "C:\LogAnalyticsScripts\" in the script, and update the dot link to the OMSDataCollector.ps1 file. Between the sign. (dot) and the file name must be 2 space characters: ". C:\LogAnalyticsScripts\OMSDataCollector.ps1"

**C:\LogAnalyticsScripts\Arch** - directory in which the script will shift files after processing. For example, in the directory C:\LogAnalyticsScripts\Reports\report.csv. After processing and uploading data to OMS Log Analytics, the file is transferred to the C:\LogAnalyticsScriptsatus\Arch directory and renamed to 20180601 report.csv

**C:\LogAnalyticsScriptstus\Log** - the directory in which the script operation log will be stored

**C:\LogAnalyticsScripts\JSON** - the directory for storing processed CSVs that are converted to JSON for sending to OMS. If a corresponding JSON file already exists for a CSV report, then no CSV re-processing will be performed. JSON will be sent to OMS as is.
**This mechanism is not used in this version of the script!!!**

# work logic
The script executes the SQL query specified in the $ Query variable.
Query results are transformed into PSObject
Certain SQL query fields must be manually assigned to the corresponding PSObject fields.
Each PSObject is added to the PS hash table
PS hash table is automatically sent to OMS

## Rules for converting SQL fields into Log Analytics fields
Given inside the function SQLtoJSON:
$ ROW - a specific line of SQL select results
Name Result - field name in OMS Log Analytics. In addition, the _s symbol will be added to the field when data is injected into the cloud.

**Attention**
You need to manually define your own structure for matching SQL select fields and data sent to OMS

Current parsing structure:
`` `
    $ UserDetails = New-Object -TypeName PSObject
    $ UserDetails | Add-Member -Type NoteProperty -Name Computer -Value $ ROW.Computer
    $ UserDetails | Add-Member -Type NoteProperty -Name ConsoleMinutes -Value $ ROW.OS
    $ UserDetails | Add-Member -Type NoteProperty -Name UniqueUserName -Value $ ROW.UniqueUserName
    $ UserDetails | Add-Member -Type NoteProperty -Name DisplayName -Value $ ROW.DisplayName0
    $ UserDetails | Add-Member -Type NoteProperty -Name Full_Domain_Name -Value $ ROW.Full_Domain_Name0
    $ UserDetails | Add-Member -Type NoteProperty -Name Mail -Value $ ROW.Mail0
    $ UserDetails | Add-Member-Type NoteProperty-Name PhysicalOffice -Value $ ROW.physicalDeliveryOfficeNam0
    $ UserDetails | Add-Member -Type NoteProperty -Name UserName -Value $ ROW.User_Name0
    $ UserDetails | Add-Member -Type NoteProperty -Name ConsoleMinutes -Value $ ROW.ConsoleMinutes
    $ UserDetails | Add-Member -Type NoteProperty -Name LastLoginTime -Value $ ROW.LastLoginTime
    $ UserDetails | Add-Member -Type NoteProperty -Name NumberOfLogins -Value $ ROW.NumberOfLogins
    $ UsersInfo + = $ UserDetails

`` `
