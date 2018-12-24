#==============================================================================
# Module name: SQLtoOMSDataSender
# Author: Alexey Taranenko (altaranenco@gmail.com)
# Version: 1.0
# Dependencies: Windows PowerShell 3.0
# Purpose: Get data from SQL (single select query) and send it to OMS\Log analytics 
# Functions list:
#   Invoke-SqlCommand 
#==============================================================================
# 3th party PowerShell functions
#
#   Invoke-SqlCommand()  
#   SQLtoJSON
#
#SYNOPSIS
#    Performs a SQL query and returns an array of PSObjects.
#NOTES
#    Author: Jourdan Templeton - hello@jourdant.me
#LINK 
#   https://blog.jourdant.me/post/simple-sql-in-powershell
#
#==============================================================================
# CHANGE LOG
# 14.12.2018 - initial version
#==============================================================================

$ScriptVersion = "1.00"

# Replace with your Workspace ID
$CustomerId = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"  

# Replace with your Primary Key
$SharedKey = "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy=="

# Specify the name of the record type that you'll be creating
$LogType = "UsersInfo_CL"

# Specify a field with the created time for the records
$TimeStampField = (Get-Date).Date


#Root folder for script. Just actulize this folder

$RootFolder="C:\LogAnalyticsScripts\"
#Path to folder constrain CSV or XLS files
$SourceFolder="Z:\"

#Folder to archive MaxPatrol XMLs after parsed and sent to OMS
$ArchFolder=$RootFolder + "Arch\"

#Folder to this script logs
$LogFolder=$RootFolder + "Log\"

#Folder for saved JSON
$JSONFolder=$RootFolder + "JSON\"

#Select your base Price Tire model for your Log Analytics, per GB or pre Node.
#If your use per Node model, you should set this parameter to $FALSE
$OMSPriceModeperGB = $TRUE

#Number of retrying to send data to OMS 
$OMSRetryNumber = 10

#Sleep seconds between of retrying to send data to OMS 
$OMSSleepTime = 60

#Set 15Mb
#$MaxJSONFileSize=15728640
#$MaxJSONFileSize=4194304
$MaxJSONFileSize = 8388608
$Log = $LogFolder + "Userinfo_toOMS_main_forIngos.log"

#Load set of base OMS Data Collector function (Write-OMSLog, New-OMSSignature, Submit-OMSData, Initialize-OMSJSON)
.  C:\LogAnalyticsScripts\OMSDataCollector.ps1

#==============================================================================
#                                SQL QUERY AND PARAMS
#==============================================================================
$Serverinstance = "msvo-sccml"
$Database = "cm_igs"
$Username = ""
$Password = ""
$Query = "select sys.Name0 AS Computer,  sys.Operating_System_Name_and0 as OS, umr.UniqueUserName, usr.DisplayName0, usr.Full_Domain_Name0, usr.Mail0, usr.physicalDeliveryOfficeNam0, usr.User_Name0, umr.UniqueUserName, umr.MachineResourceID, umi.ConsoleMinutes, umi.LastLoginTime, umi.NumberOfLogins
from v_R_User usr
LEFT JOIN v_UserMachineRelationship umr  on usr.Unique_User_Name0 = umr.UniqueUserName
LEFT JOIN v_R_System sys ON sys.ResourceID =umr.MachineResourceID
LEFT JOIN v_UserMachineIntelligence umi ON umr.MachineResourceID = umi.MachineResourceID
WHERE sys.Operating_System_Name_and0 NOT LIKE '%Server%'
order by Computer"
#==============================================================================

function Invoke-SqlCommand() {
    [cmdletbinding(DefaultParameterSetName="integrated")]Param (
        [Parameter(Mandatory=$true)][Alias("Serverinstance")][string]$Server,
        [Parameter(Mandatory=$true)][string]$Database,
        [Parameter(Mandatory=$true, ParameterSetName="not_integrated")][string]$Username,
        [Parameter(Mandatory=$true, ParameterSetName="not_integrated")][string]$Password,
        [Parameter(Mandatory=$false, ParameterSetName="integrated")][switch]$UseWindowsAuthentication = $true,
        [Parameter(Mandatory=$true)][string]$Query,
        [Parameter(Mandatory=$false)][int]$CommandTimeout=0
    )
    
    #build connection string
    $connstring = "Server=$Server; Database=$Database; "
    If ($PSCmdlet.ParameterSetName -eq "not_integrated") { $connstring += "User ID=$username; Password=$password;" }
    ElseIf ($PSCmdlet.ParameterSetName -eq "integrated") { $connstring += "Trusted_Connection=Yes; Integrated Security=SSPI;" }
    
    #connect to database
    $connection = New-Object System.Data.SqlClient.SqlConnection($connstring)
    $connection.Open()
    
    #build query object
    $command = $connection.CreateCommand()
    $command.CommandText = $Query
    $command.CommandTimeout = $CommandTimeout
    
    #run query
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataset) | out-null
    
    #return the first collection of results or an empty array
    If ($dataset.Tables[0] -ne $null) {$table = $dataset.Tables[0]}
    ElseIf ($table.Rows.Count -eq 0) { $table = New-Object System.Collections.ArrayList }
    
    $connection.Close()
    return $table
}

function SQLtoJSON  ($SQLTab)
{   
    Write-OMSLog -Message "Starting convert SQL query to PS Object" -Level Info -Path $Log
    

    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    $UsersInfo = @()

    foreach($ROW in $SQLTab)
    {
        $UserDetails = New-Object -TypeName PSObject
        $UserDetails| Add-Member -Type NoteProperty -Name Computer -Value $ROW.Computer
        $UserDetails| Add-Member -Type NoteProperty -Name ConsoleMinutes -Value $ROW.OS
        $UserDetails| Add-Member -Type NoteProperty -Name UniqueUserName -Value $ROW.UniqueUserName
        $UserDetails| Add-Member -Type NoteProperty -Name DisplayName -Value $ROW.DisplayName0
        $UserDetails| Add-Member -Type NoteProperty -Name Full_Domain_Name -Value $ROW.Full_Domain_Name0
        $UserDetails| Add-Member -Type NoteProperty -Name Mail -Value $ROW.Mail0
        $UserDetails| Add-Member -Type NoteProperty -Name PhysicalOffice -Value $ROW.physicalDeliveryOfficeNam0
        $UserDetails| Add-Member -Type NoteProperty -Name UserName -Value $ROW.User_Name0
        $UserDetails| Add-Member -Type NoteProperty -Name ConsoleMinutes -Value $ROW.ConsoleMinutes
        $UserDetails| Add-Member -Type NoteProperty -Name LastLoginTime -Value $ROW.LastLoginTime
        $UserDetails| Add-Member -Type NoteProperty -Name NumberOfLogins -Value $ROW.NumberOfLogins
        $UsersInfo += $UserDetails
    }
    Write-OMSLog -Message "Finished work with SQL query" -Level Info -Path $Log
    return $UsersInfo
}

#==============================================================================
#==============================================================================
#                                MAIN BODY
#==============================================================================
#==============================================================================

Write-OMSLog -Message "Script started..." -Level Info -Path $Log
Write-OMSLog -Message "Script version: $ScriptVersion" -Level Info -Path $Log
Write-OMSLog -Message "Run SQL query for server: $Serverinstance" -Level Info -Path $Log

if (($Username -eq "") -or ($Password -eq "") -or ($null -eq $Username) -or ($null -eq $Password))
{
    Write-OMSLog -Message "Connect SQL server based on Windows Authentication" -Level Info -Path $Log
    $SQLTab =  Invoke-SqlCommand -Server $Serverinstance -Database $Database -UseWindowsAuthentication -Query $Query
}
else {
    Write-OMSLog -Message "Connect SQL server based on username and passoword" -Level Info -Path $Log
    $SQLTab =  Invoke-SqlCommand -Server $Serverinstance -Database $Database -Username $Username -Password $Password -Query $Query
}

$JSON = SQLtoJSON $SQLTab 
 
if ($JSON -ne $null)
{
    if ($JSON.Length -gt 2)
    { 
        Initialize-OMSJSON -InitialObject $JSON -MaxJSONSize $MaxJSONFileSize -LogFile $Log        
    }
    else
    {
        Write-OMSLog -Message "JSON file NULL. Nothing to send..." -Level Info -Path $Log
    }
}
else
{
    Write-OMSLog -Message "JSON file NULL. Nothing to send..." -Level Info -Path $Log
}  

Write-OMSLog -Message "Script stopped..." -Level Info -Path $Log
