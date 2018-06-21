#==============================================================================
# Mobule name: OMSDataCollector
# Author: Alexey Taranenko (altaranenco@gmail.com)
# Version: 1.0
# Dependencies: Windows PowerShell 3.0
# Date of Last Change: 15 June 2018
# Changes: New Script
# Purpose: Base set of PowerShell funtions for OMS\Log analytics data collector
# https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-collector-api
# Functions list:
#   Write-OMSLog
#   New-OMSSignature
#   Submit-OMSData
#   Initialize-OMSJSON
#==============================================================================
# 3th party PowerShell functions
#
# Write-OMSLog 
#   Created by: Jason Wasser @wasserja 
#   Modified: 11/24/2015 09:30:19 AM
#   Small customization: Alexey Taranenko, 31 May 2017
#   https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0 
# 
# New-OMSSignature
#   Created by: Microsoft
#   https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-collector-api#sample-requests
# 
# Submit-OMSData
#   Created by: Microsoft
#   https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-collector-api#sample-requests
#
#
#==============================================================================
# CHANGE LOG
# 14.05.2018 - initial version
#==============================================================================

function Write-OMSLog 
{ 

    [CmdletBinding()] 
    Param 
    ( 
        [Parameter(Mandatory=$true, 
                   ValueFromPipelineByPropertyName=$true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias("LogContent")] 
        [string]$Message, 
 
        [Parameter(Mandatory=$true, 
                   ValueFromPipelineByPropertyName=$true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias('LogPath')] 
        [string]$Path, 
         
        [Parameter(Mandatory=$false)] 
        [ValidateSet("Error","Warn","Info")] 
        [string]$Level="Info", 
         
        [Parameter(Mandatory=$false)] 
        [switch]$NoClobber 
    ) 
 
    Begin 
    { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue' 
    } 
    Process 
    { 
         
        # If the file already exists and NoClobber was specified, do not write to the log. 
        if ((Test-Path $Path) -AND $NoClobber) { 
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name." 
            Return 
            } 
 
        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path. 
        elseif (!(Test-Path $Path)) { 
            Write-Verbose "Creating $Path." 
            $NewLogFile = New-Item $Path -Force -ItemType File 
            } 
 
        else { 
            # Nothing to see here yet. 
            } 
 
        # Format Date for our Log File 
        #$FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss" 
        $FormattedDate = Get-Date -Format "dd-MM-yyyy HH:mm:ss" 
 
        # Write message to error, warning, or verbose pipeline and specify $LevelText 
        switch ($Level) { 
            'Error' { 
                Write-Error $Message 
                $LevelText = 'ERROR:' 
                } 
            'Warn' { 
                Write-Warning $Message 
                $LevelText = 'WARNING:' 
                } 
            'Info' { 
                Write-Verbose $Message 
                $LevelText = 'INFO:' 
                } 
            } 
         
        # Write log entry to $Path         
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append 
    } 
    End 
    { 
    } 
}

Function New-OMSSignature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource){
    <#
    .SYNOPSIS
        # The function to create the authorization signature
    .DESCRIPTION
        The function to create the authorization signature
    #>
    Begin 
    { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue' 
    } 
    Process 
    {
        # originaly from: https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-collector-api#sample-requests
        $xHeaders = "x-ms-date:" + $date
        $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
    
        $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
        $keyBytes = [Convert]::FromBase64String($sharedKey)
    
        $sha256 = New-Object System.Security.Cryptography.HMACSHA256
        $sha256.Key = $keyBytes
        $calculatedHash = $sha256.ComputeHash($bytesToHash)
        $encodedHash = [Convert]::ToBase64String($calculatedHash)
        $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
        return $authorization    
    }
}

Function Submit-OMSData(){
    <#
    .SYNOPSIS
        Sending Data to OMS
    .DESCRIPTION
        Sending Data to OMS
    .EXAMPLE
        Submit-OMSData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($JSONParts)) -logType $logType -RetryNumber 10 -SleepTime 60 -LogFile 'C:\Log\log.txt'
    .PARAMETER customerId
        The unique identifier for the Log Analytics workspace.
    .PARAMETER sharedKey
        The unique Primary or Secondary key for the Log Analytics workspace.
    .PARAMETER body
        The body send to OMS
    .PARAMETER logType
        Specify the record type of the data that is being submitted. Currently, the log type supports only alpha characters. It does not support numerics or special characters. The size limit for this parameter is 100 characters.
    .PARAMETER RetryNumber
        Number of retry attempts. Default 10
    .PARAMETER SleepTime
        Pause for a few seconds before resending. Default 60 second
    .PARAMETER LogFile
        The path to the log file    
    #>
    param (
        [PARAMETER(Mandatory=$True,Position=0)][String]$customerId,
        [PARAMETER(Mandatory=$True,Position=1)][String]$sharedKey,
        [PARAMETER(Mandatory=$True,Position=2)]$body,
        [PARAMETER(Mandatory=$True,Position=3)][String]$logType,
        [PARAMETER(Mandatory=$False,Position=4)]$RetryNumber=10,
        [PARAMETER(Mandatory=$False,Position=5)]$SleepTime=60,
        [PARAMETER(Mandatory=$True,Position=6)][String]$LogFile
        )
    Begin 
    { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue' 
    } 
    Process 
    {
           # originaly from: https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-collector-api#sample-requests
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = New-OMSSignature `
        -customerId $customerId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -fileName $fileName `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }
   
    $retryCounter = 1
    while ($retryCounter -le $RetryNumber) 
    {
        Write-OMSLog -Message "Trying to send data to OMS. Trying $retryCounter of $RetryNumber" -Level Info -Path $LogFile

        $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
        $StatusCode = $response.StatusCode
        $retryCounter ++
        if ($StatusCode -eq 200) 
        {
            Write-OMSLog -Message "The data successfully sended to OMS. Retry code: $StatusCode" -Level Info -Path $LogFile
            break
        }        
        Write-OMSLog -Message "Failed attempt to send data to OMS. Try againe" -Level Warn -Path $LogFile
        Start-Sleep -s $SleepTime
    }
    
    if ($StatusCode -ne 200 -and ($retryCounter -ge $RetryNumber))
    {
        Write-OMSLog -Message "Cannot send data to OMS. Contunue the script" -Level Error -Path $LogFile
    }
    return $StatusCode
    }

}

Function Initialize-OMSJSON(){
    <#
    .SYNOPSIS
        Preparing a JSON file for sending to OMS with a send size limit
    .DESCRIPTION
        This function prepares JSON for sending to OMS, taking into account the limitation of the size of the transmitted JSON for 1 reception
    .EXAMPLE
        #Initialize-OMSJSON -InitialObject $JSON -MaxJSONSize 1024 -LogFile 'C:\Log\log.txt'
    .EXAMPLE
    .PARAMETER InitialObject
        The initial JSON that will be sent to OMS
    .PARAMETER MaxJSONSize
        Maximum JSON size in one send
    .PARAMETER LogFile
        The path to the log file 
    #>
    param (
        [PARAMETER(Mandatory=$True,Position=0)]$InitialObject,
        [PARAMETER(Mandatory=$False,Position=1)]$MaxJSONSize=8388608,
        [PARAMETER(Mandatory=$True,Position=2)][String]$LogFile
        )
    Begin 
    { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue' 
    } 
    Process 
    {
        if ($InitialObject -ne $null)
        {
            #Convert an object to JSON to understand its resulting size
            $JSONArray = $InitialObject | ConvertTo-Json
            if($JSONArray.Length -gt $MaxJSONSize)
            {
                Write-OMSLog -Message ("JSON file size: "+$JSONArray.Length) -Level Info -Path $LogFile
                Write-OMSLog -Message "JSON file size greate at: $MaxJSONSize bytes. Split it " -Level Info -Path $LogFile
                #Determine how many times the file size violates the constraint. We round to the larger whole.
                #Determine the number of elements in the array and divide it by the excess ratio
                #Next, we will work with data packets, not with an entire array

                $CurrentvsMaxSize = [math]::Ceiling($JSONArray.Length/$MaxJSONSize)       
                Write-OMSLog -Message "Parts to send: $CurrentvsMaxSize"  -Level Info -Path $LogFile
                    
                $ObjPartSize=[math]::Round($InitialObject.Length/$CurrentvsMaxSize)
                Write-OMSLog -Message "Items in one part: $ObjPartSize" -Level Info -Path $LogFile
    
                $Arr_Start_Elements=0
                $Arr_End_Elements=$ObjPartSize
    
                for($n=0 ; $n -lt $CurrentvsMaxSize ; $n++)
                {
                    #Determine the size of the parts. and how to process them                      
                    Write-OMSLog -Message "Starting process part $n" -Level Info -Path $LogFile
                    $JSONParts = $InitialObject[$Arr_Start_Elements..$Arr_End_Elements] | ConvertTo-Json 
    
                    Write-OMSLog -Message "From $Arr_Start_Elements to $Arr_End_Elements" -Level Info -Path $LogFile    
                    Write-OMSLog -Message "Trying to send part $n data to OMS" -Level Info -Path $LogFile
    
                    $Arr_Start_Elements = $Arr_End_Elements+1
                    $Arr_End_Elements += $ObjPartSize    
     
                    $OMSPostResult= Submit-OMSData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($JSONParts)) -logType $logType -RetryNumber $OMSRetryNumber -SleepTime $OMSSleepTime -LogFile $LogFile                                   

                }    
            }
            else
            {
                    Write-OMSLog -Message "JSON size - OK" -Level Info -Path $LogFile
                    Write-OMSLog -Message "Trying to send data to OMS" -Level Info -Path $LogFile
                    $JSONParts = $InitialObject | ConvertTo-Json  
                    $OMSPostResult = Submit-OMSData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($JSONParts)) -logType $logType -RetryNumber $OMSRetryNumber -SleepTime $OMSSleepTime -LogFile $LogFile               
            } 
        }
        else
        {
            Write-OMSLog -Message "JSON file NULL. Nothing to send..." -Level Info -Path $LogFile
        }

        return $OMSPostResult       

    }              
}