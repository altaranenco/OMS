#==============================================================================
# author: Alexey Taranenko (altara@microsoft.com)
# Convert XML reports from Max Patrol to JSON and post it to OMS
#==============================================================================
# CHANGE LOG
# 19.06.2017 - add - Support for big (more 30Mb) JSON file. Use MaxJSONFileSize to set max size per separate JSON
# 19.06.2017 - add - Do not re-convert XML if JSON already exists as a saved file
# 19.06.2017 - add - Add ScriptVersion parametr
# 27.06.2017 - add - Add IP address to JSON
# 18.07.2017 - add - If FQDN empty, use NetBIOS. If NetBIOS also empty, use IP
# 01.10.2017 - add - Trying to send data to OMS if first atempt was unsuccessful
# 27.10.2017 - change - Change Get-Content to [System.IO.File]::ReadAllLines to improve load speed
# 18.06.2018 - change - Move all general functions to separate file: OMSDataCollector.ps1. This file should load via dot-sourcing
#==============================================================================

$ScriptVersion = "2.00"

# Replace with your Workspace ID
$CustomerId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  

# Replace with your Primary Key
$SharedKey = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=="

# Specify the name of the record type that you'll be creating
$LogType = "Vulner_CL"

# Specify a field with the created time for the records
$TimeStampField = (Get-Date).Date

#Path to folder constrain MaxPatrol XMLs
$MaxPatrolFolder="C:\MaxPatrol_Reports\XML\"


#Folder to archive MaxPatrol XMLs after parsed and sent to OMS
$MaxPatrolArch="C:\MaxPatrol_Reports\Arch\"

#Folder to this script logs
$LogFolder="C:\MaxPatrol_Reports\Log\"

#Folder for saved JSON
$JSONFolder="C:\MaxPatrol_Reports\JSON\"

#Number of retrying to send data to OMS 
$OMSRetryNumber = 10

#Sleep seconds between of retrying to send data to OMS 
$OMSSleepTime = 60

#Set 15Mb
#$MaxJSONFileSize=15728640
#$MaxJSONFileSize=4194304
$MaxJSONFileSize = 8388608
$Log = $LogFolder + "MaxPatrolXMLtoOMS_main.log"

#Load set of base OMS Data Collector function (Write-OMSLog, New-OMSSignature, Submit-OMSData, Initialize-OMSJSON)
.  C:\MaxPatrol_Reports\OMSDataCollector.ps1
#==============================================================================

function XMLtoJSON  ($XMLPath)
{
    $LogFile = ''
    $GUID = [guid]::NewGuid() 
    $LogFile = $LogFolder + $GUID + ".log"
       
    Write-OMSLog -Message "Starting read a XML file: $XMLPath" -Level Info -Path $Log
    
    [xml]$XML = [System.IO.File]::ReadAllLines((Resolve-Path $XMLPath))    
    
    Write-OMSLog -Message "Finished read a XML file: $XMLPath" -Level Info -Path $Log
    $VulnerArray = $xml.content.vulners.vulner | where-object {$_.cvss -ne $NULL -and $_.PubDate -ne '' -and $_.global_id -ne $NULL}

    for( $i = 0 ; $i -lt $VulnerArray.Count ; $i++ ) 
    {   
       if ($VulnerArray[$i].short_description -eq '') 
            {$VulnerArray[$i].short_description = "N\A"}

       if ($VulnerArray[$i].title -eq '') 
            {$VulnerArray[$i].title = "N\A"} 

       if ($VulnerArray[$i].description -eq '') 
            {$VulnerArray[$i].description = "N\A"} 

       if ($VulnerArray[$i].how_to_fix -eq '') 
            {$VulnerArray[$i].how_to_fix = "N\A"} 

#       if ($VulnerArray[$i].PubDate -eq $NULL) 
#            {$VulnerArray[$i].PubDate += "N\A"} 

#       if ($VulnerArray[$i].global_id -eq $NULL) 
#            {$VulnerArray[$i].global_id += @{"name" = "N\A"; "value" = "N\A"}} 

       if ($VulnerArray[$i].links -eq '') 
            {$VulnerArray[$i].links = "N\A"} 
    }
   
    Write-OMSLog -Message "Added missing value to Vulners array items" -Level Info -Path $Log

    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    $VulnerInfo = @()

    foreach ($ScanHost in $xml.content.data.host)
    {
        foreach ($ScanSoft in $ScanHost.scan_objects.soft)
            {
              if($ScanSoft.vulners -ne $NULL) 
              {  
               # Write-OMSLog -Message "Starting JOIN operation" -Level Info -Path $Log

                foreach ($Vulner in $ScanSoft.vulners.vulner) 
                {   
                    if(($Vulner.Level -ne 0) -and ($Vulner.BaseScore -ne 0))
                    {
                        $VulnerObj = $VulnerArray | Where-Object {$_.id -eq $Vulner.id}  
                        $BaseScore =   [double]$VulnerObj.cvss.base_score

                        if($BaseScore -ne 0)
                        {                            
                            $ScanResult = New-Object -TypeName PSObject

                            $ScanResult | Add-Member -Type NoteProperty -Name ScanDate -Value $ScanHost.start_time 
                            if($ScanHost.fqdn -ne '')
                            {
                                $ScanResult | Add-Member -Type NoteProperty -Name Host -Value $ScanHost.fqdn
                            }
                            else
                            {                    
                                if($ScanHost.netbios -ne '')
                                {
                                    $ScanResult | Add-Member -Type NoteProperty -Name Host -Value $ScanHost.netbios
                                }
                                else
                                {
                                    $ScanResult | Add-Member -Type NoteProperty -Name Host -Value $ScanHost.ip 
                                }
                            }                  
                                                
                            $ScanResult | Add-Member -Type NoteProperty -Name IP -Value $ScanHost.ip 
                            
                            $ScanResult | Add-Member -Type NoteProperty -Name TaskName -Value $xml.content.tasks.task.name
                            
                            $AppFullName =  $ScanSoft.name + " " + $ScanSoft.version
        
                            $ScanResult | Add-Member -Type NoteProperty -Name AppPath -Value $ScanSoft.path 
        
                            $ScanResult | Add-Member -Type NoteProperty -Name AppName -Value $AppFullName  
        
                            $ScanResult | Add-Member -Type NoteProperty -Name MaxPatrolID -Value $VulnerObj.id   
                            
                            $ScanResult | Add-Member -Type NoteProperty -Name Description -Value $VulnerObj.description
        
                            $BaseScore =   [double]$VulnerObj.cvss.base_score
                            $ScanResult | Add-Member -Type NoteProperty -Name BaseScore -Value $BaseScore                  
                                                                
                            #$ScanResult | Add-Member -Type NoteProperty -Name AppVersion -Value $ScanSoft.version
                            $ScanResult | Add-Member -Type NoteProperty -Name GlobalID -Value $VulnerObj.global_id.value
        
                            switch ($Vulner.level)
                            {
                                1 {
                                    $ScanResult | Add-Member -Type NoteProperty -Name Level -Value "Low Risk"
                                    $DiffScore =  [math]::Round($BaseScore * 1,2)
                                    $ScanResult | Add-Member -Type NoteProperty -Name DiffScore -Value $DiffScore
                                    } 
                                3 {
                                    $ScanResult | Add-Member -Type NoteProperty -Name Level -Value "Medium Risk"
                                    $DiffScore = [math]::Round($BaseScore * 2,2)
                                    $ScanResult | Add-Member -Type NoteProperty -Name DiffScore -Value $DiffScore
                                    } 
                                5 {
                                    $ScanResult | Add-Member -Type NoteProperty -Name Level -Value "High Risk"
                                    $DiffScore = [math]::Round($BaseScore * 3,2)
                                    $ScanResult | Add-Member -Type NoteProperty -Name DiffScore -Value $DiffScore
                                    }
                                defaul {$ScanResult | Add-Member -Type NoteProperty -Name Level -Value "N\A"}
                            }
                            #$ScanResult | Add-Member -Type NoteProperty -Name Level -Value $Vulner.level
                            $ScanResult | Add-Member -Type NoteProperty -Name PubDate -Value $VulnerObj.publication_date

                            $ScanResult | Add-Member -Type NoteProperty -Name Links -Value $VulnerObj.links
                            
                            $ScanResult | Add-Member -Type NoteProperty -Name VulnerScanner -Value "Max Patrol"
        
                            $VulnerInfo += $ScanResult   
                        }
                    }
                }
              }
            }
    }        
   return $VulnerInfo
}

function MoveOldFiles($XMLs)
{

    #$MaxPatrolFolder="C:\MaxPatrol_Reports\"
    #$AuditXMLs = Get-ChildItem $MaxPatrolFolder -Filter "*.xml"
    #$timeinfo = '17.01.2017 10-00-00'
    $template = 'dd.MM.yyyy HH-mm-ss'

    $filelist = @()
    foreach ($XML in $XMLs)
    {    
        $splitfile = $XML -split "\w*(\d\d.\d\d.\d\d\d\d \d\d\-\d\d\-\d\d)"
        $filedetail = New-Object -TypeName PSObject
        $filedetail | Add-Member -Type NoteProperty -Name FileName -Value $splitfile.Get(0)
        $filedetail | Add-Member -Type NoteProperty -Name FileDate -Value ([DateTime]::ParseExact($splitfile.Get(1), $template, $null))
        $filedetail | Add-Member -Type NoteProperty -Name FullName -Value $XML.FullName
        $filelist+=$filedetail
    }

    $Groups = $filelist | Sort-Object -Property @{Expression = "FileName"; Descending = $FALSE}, @{Expression = "FileDate"; Descending = $TRUE} | Group-Object -Property FileName
    foreach ($group in $Groups)
    {
        if($group.count -gt 1)
        {
            $movefile = $group.group | Select-Object -Skip 1       
            
            Move-Item $movefile.FullName $MaxPatrolArch -Force -Verbose 
            Write-OMSLog "Move origin XML to Archive folder: $movefile" -Level Info -Path $Log
        }
    }
}

function PrepareJSONtoSave($RAWJSON)
{
    $dReplacements = @{
        "\\u003c" = "<"
        "\\u003e" = ">"
        "\\u0027" = "'"
    }        

    foreach ($oEnumerator in $dReplacements.GetEnumerator()) {
        $sRawJson = $RAWJSON -replace $oEnumerator.Key, $oEnumerator.Value
    }

    return $sRawJson
}

#==============================================================================
#==============================================================================
#                                MAIN BODY
#==============================================================================
#==============================================================================
#cls
Write-OMSLog -Message "MaxPatrolXMLtoOMS script started..." -Level Info -Path $Log
Write-OMSLog -Message "Script version: $ScriptVersion" -Level Info -Path $Log

#Проверяем и удаляем старые отчеты. Для каждой категории должен остаться только один, самый новый
Write-OMSLog -Message "Check and move old report to archive folder..." -Level Info -Path $Log
MoveOldFiles (Get-ChildItem $MaxPatrolFolder -Filter "*.xml")

#Повтоно запрашиваем директорию и начинаем работать
$AuditXMLs = Get-ChildItem $MaxPatrolFolder -Filter "*.xml"

#Обрабатываем каждый файл отдельно
foreach ($AuditXML in $AuditXMLs) 
{      
 
    Write-OMSLog -Message "Work at file: $AuditXML" -Level Info -Path $Log    

    #$JSONFile = $LogFolder + $AuditXML.Name + ".json"
    $JSONFile = $JSONFolder + $AuditXML.Name + ".json"
    if(Get-Item $JSONFile -ErrorAction SilentlyContinue) 
    {
        Write-OMSLog -Message "$JSONFile file already exis. Use it" -Level Info -Path $Log
        $sJson = Get-Content -Path $JSONFile | Out-String
        $JSON = PrepareJSONtoSave $sJson | ConvertFrom-Json
    }
    else
    {
        Write-OMSLog -Message "$JSONFile file doent' exis. Create it" -Level Info -Path $Log
        #Чистим и конвертируем XML в JSON
        $ArrayObj = XMLtoJSON $AuditXML.FullName
        $JSON = $ArrayObj | ConvertTo-Json     

        #готовим JSON для записи в файл
        PrepareJSONtoSave $JSON | Out-File -FilePath $JSONFile      
        Write-OMSLog -Message "Save JSON to file: $JSONFile" -Level Info -Path $Log
        Write-OMSLog -Message "Reload JSON from file: $JSONFile" -Level Info -Path $Log
        $sJson = Get-Content -Path $JSONFile | Out-String
        $JSON = PrepareJSONtoSave $sJson | ConvertFrom-Json
    }    

    #проверяем полученный $JSON. Иногда он может быть пустым или содержать только символ переноса на новую строку. Обрабатываем это и отправляем в OMS
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
    <#
    if ($JSON -ne $null)
    {
        if ($JSON.Length -gt 2)
        {        
            if((Get-Item $JSONFile -ErrorAction SilentlyContinue).Length -gt $MaxJSONFileSize)
            {
                #Определяем, во сколько раз размер файла нарушает ограничение. Округляем до большего целого.
                #Определяем количество элементов в массиве и делим его на коэффициент превышения
                #Далее будем работать с пачками данных, а не с целым массивом

                #(Get-Item $JSONFile).Length
                $JSONElemets = $JSON.Length
                $CurrentvsMaxSize = [math]::Ceiling((Get-Item $JSONFile).Length/$MaxJSONFileSize)
                        
                $JSONPartsSize=[math]::Round($JSONElemets/$CurrentvsMaxSize)
                Write-OMSLog -Message ("JSON file size: "+(Get-Item $JSONFile).Length) -Level Info -Path $Log
                Write-OMSLog -Message "JSON file size greate at: $MaxJSONFileSize bytes. Split it " -Level Info -Path $Log
                Write-OMSLog -Message "Elements in JSON files: $JSONElemets" -Level Info -Path $Log
                Write-OMSLog -Message "Total number of parts to send: $CurrentvsMaxSize" -Level Info -Path $Log
                #Номер текущей партии            
                
                $JSON_Strart_Elements=0
                $JSON_END_Elements=$JSONPartsSize

                for($n=0 ; $n -lt $CurrentvsMaxSize ; $n++)
                {
                    #определиться с размерами частей. и с тем как их обрабатывать
                                
                
                    $JSONParts=$JSON[ $JSON_Strart_Elements..$JSON_END_Elements] | ConvertTo-Json  
                    Write-OMSLog -Message "From $JSON_Strart_Elements to $JSON_END_Elements" -Level Info -Path $Log
                    Write-OMSLog -Message "Trying to send part $n data to OMS" -Level Info -Path $Log
                    $JSON_Strart_Elements = $JSON_END_Elements+1
                    $JSON_END_Elements+=$JSONPartsSize

                    $OMSPostResult=(Post-OMSData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($JSONParts)) -logType $logType).StatusCode

                    Write-OMSLog -Message "Status Code: $OMSPostResult"   -Level Info -Path $Log                    
                }     

            }
            else
            {
                Write-OMSLog -Message "JSON file size - OK" -Level Info -Path $Log
                Write-OMSLog -Message "Trying to send data to OMS" -Level Info -Path $Log
                $JSONParts= $JSON | ConvertTo-Json 
                $OMSPostResult =(Post-OMSData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($JSONParts)) -logType $logType).StatusCode
                Write-OMSLog -Message "Status Code: $OMSPostResult"   -Level Info -Path $Log
            }
        
            #Check ScanDate in XML. If this date oldest that NOW-$DaysToOblsolete we shoulde move file to Archive folver
     #       Write-OMSLog -Message "Check ScanDate in XML" -Level Info -Path $Log
     #       if ((get-date $ArrayObj.Get(0).ScanDate) -lt ((Get-Date).AddDays(-$DaysToObsolete)))
     #       {            
     #           Move-Item $AuditXML.FullName $MaxPatrolArch -Force -Verbose 
     #           Write-OMSLog "Move origin XML to Archive folder" -Level Info -Path $Log
     #       }
        
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
    #>
}

Write-OMSLog -Message "MaxPatrolXMLtoOMS script stoped..." -Level Info -Path ($LogFolder+"MaxPatrolXMLtoOMS_main.log")