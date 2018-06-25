#==============================================================================
# author: Alexey Taranenko (altara@microsoft.com)
# Send CSV with MFA Report to OMS Log Analytics
#==============================================================================
# CHANGE LOG
# 14.05.2018 - initial version
# 25.06.2018 - change - Move all general functions to separate file: OMSDataCollector.ps1. This file should load via dot-sourcing
#==============================================================================

$ScriptVersion = "2.00"

# Replace with your Workspace ID
$CustomerId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  

# Replace with your Primary Key
$SharedKey = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=="

# Specify the name of the record type that you'll be creating
$LogType = "IngosMFA_CL"

# Specify a field with the created time for the records
$TimeStampField = (Get-Date).Date


#Root folder for script. Just actulize this folder

$RootFolder="C:\MFAStatus\"
#Path to folder constrain CSV or XLS files
$SourceFolder=$RootFolder+"Reports\"
#$Status2FA_File = $SourceFolder + '2FA disabled.csv'


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
$Log = $LogFolder + "MFAReporttoOMS_main.log"

#Load set of base OMS Data Collector function (Write-OMSLog, New-OMSSignature, Submit-OMSData, Initialize-OMSJSON)
.  C:\MFAStatus\OMSDataCollector.ps1

#==============================================================================
function CSVtoJSON  ($CurrentFile)
{   
    Write-OMSLog -Message "Starting read a file: $CurrentFile" -Level Info -Path $Log
    $MFAArray = Import-Csv $CurrentFile -Delimiter ";" 
    Write-OMSLog -Message "Finished read a file: $CurrentFile" -Level Info -Path $Log

    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    $MFAResultObject = @()

    foreach ($ROW in $MFAArray)
    {
        $MFAObject = New-Object -TypeName PSObject

        $TimeStamp = [System.Convert]::ToDateTime($ROW.EventTime)
        $MFAObject | Add-Member -Type NoteProperty -Name Time -Value $TimeStamp
        $MFAObject | Add-Member -Type NoteProperty -Name Result -Value $ROW.Result
        $MFAObject | Add-Member -Type NoteProperty -Name MethodName -Value $ROW.ServiceMethodName
        $MFAObject | Add-Member -Type NoteProperty -Name IP -Value $ROW.IP
        $MFAObject | Add-Member -Type NoteProperty -Name PasswordHash -Value $ROW.PasswordHash
        $MFAObject | Add-Member -Type NoteProperty -Name EnteredHash -Value $ROW.UserInputPasswordHash
        $MFAObject | Add-Member -Type NoteProperty -Name Account -Value $ROW.UserLogin

        $Autorize = [System.Convert]::ToBoolean($ROW.AuthSuccess)
        $MFAObject | Add-Member -Type NoteProperty -Name Autorization -Value $Autorize

        $2FA = [System.Convert]::ToBoolean($ROW.'2FactUathType')
        $MFAObject | Add-Member -Type NoteProperty -Name 2FA -Value $2FA

        $MFAResultObject += $MFAObject
    }
    Write-OMSLog -Message "Finished work with file: $CurrentFile" -Level Info -Path $Log
    return $MFAResultObject
}

#==============================================================================
#==============================================================================
#                                MAIN BODY
#==============================================================================
#==============================================================================

Write-OMSLog -Message "Script started..." -Level Info -Path $Log
Write-OMSLog -Message "Script version: $ScriptVersion" -Level Info -Path $Log

$CSVFiles = Get-ChildItem $SourceFolder -Filter "*.csv"

#Обрабатываем каждый файл отдельно
foreach ($CurrentFile in $CSVFiles) 
{   
    Write-OMSLog -Message "Starting read a file: $CurrentFile" -Level Info -Path $Log
    $JSON = CSVtoJSON $CurrentFile.FullName 

    if ($JSON -ne $null)
    {
        if ($JSON.Length -gt 2)
        { 
            $OMSPostResult = Initialize-OMSJSON -InitialObject $JSON -MaxJSONSize $MaxJSONFileSize -LogFile $Log        
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

    #переносим файл в архив
    if ($OMSPostResult -eq 200)
    {        
        $NewFileName = [string](Get-Date($currentFile.CreationTime) -Format FileDate) + " " + [string]$CurrentFile.Name
        $DestFile = $ArchFolder + $NewFileName
        Write-OMSLog "New file name in Archive folder: $NewFileName" -Level Info -Path $Log

        Move-Item -Path $CurrentFile.fullname -Destination $DestFile -Force -Verbose     
        Write-OMSLog "Move origin file to Archive folder: $ArchFolder" -Level Info -Path $Log
    }
}   
Write-OMSLog -Message "Script stopped..." -Level Info -Path $Log