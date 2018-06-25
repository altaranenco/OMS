# О скрипте Status2FA.ps1
Данный скрипт (вместе с OMSDataCollector.ps1) предназначен для отправки отчетов о состоянии MFA для определенных пользователей в Microsoft OMS (Log Analytics). Интеграция отчетов MaxPatrol с OMS позволяет получить удобный, полезный и красивый механизм обработки данных об состоянии MFA. 
Кроме того, данный скрипт может быть использован как пример работы по загрузке CSV файлов в OMS Log Analytics с разбором по полям. 
**Внимание**
Не забудьте поменять переменные в скрипте!!!

# Предварительные требования
Для передачи CSV файлов в Microsoft OMS (Log Analytics) вам необходимо:
- пространство Microsoft Log Analytics
- файлы CSV в кодировке UTF-8, с разделителем ; Если у вас другие параметры файла, не забудьте поменять это в скрпте
- скрипт [Status2FA.ps1](https://github.com/altaranenco/OMS/blob/master/CSV/Status2FA.ps1) и [OMSDataCollector.ps1](https://github.com/altaranenco/OMS/blob/master/OMSDataCollector.ps1) должны находить в одной папке, например C:\MFAStatus\
- доступ в интернет к серверам OMS\Log Analytics по 443 порту, с сервера на котором будут запускаться скрипты PowerShell
- вручную созданная структура каталогов для работы, подробнее об этом ниже

# Настройка скрипта Status2FA.ps1 перед первым использованием
## ID пространства и ключ
Log Analytics Workplace ID и ключ задаются переменными: $CustomerId и $SharedKey в шапке скрипта Status2FA.ps1

## Структура каталогов 
Для правильной работы скрипта необходимо предварительно **вручную** создать структуру каталогов:
**C:\MFAStatus** - корневая директория скрипта. В корне должны быть расположены файлы Status2FA.ps1 и OMSDataCollector.ps1. Если вы используете другую директорую, не C:\MFAStatus не забудьте в скрипте поменять значение переменной $RootFolder="C:\MFAStatus\", и обновить дот-ссылку на файл OMSDataCollector.ps1. Между знаком . (точка) и именем файла должно быть 2 знака пробела: ".  C:\MFAStatus\OMSDataCollector.ps1"

**C:\MFAStatus\Status** - базовый каталог для оригинальных CSVс реестром MFA. Можно указать сетевой ресурс в качестве источника данных. В скрипте задается переменной $SourceFolder

**C:\MFAStatus\Arch** - каталог, в который скрипт будет перекладывать устаревшие файлы. Например в каталоге одновременно расположены два файла: 
- MFA array 02.04.2018 00-31-01.csv
- MFA array 03.04.2018 00-31-00.csv

при запуске скрипта, файл MFA Array 02.04.2018 00-31-01.xml будет перемещен в каталог C:\MFAStatus\Arch\ без обработки
**данный механизм не используется в этой версии скрипта!!!**

**C:\MFAStatus\Log** - каталог, в котором будет храниться журнал работы скрипта

**C:\MFAStatus\JSON** - каталог для хранения обработанных CSV, которые сконвертированные в JSON для отправки в OMS. Если для отчета CSV уже существует соответсвующий файл JSON, то повторная обработка CSV проводиться не будет. JSON будет отправлен в OMS как есть. 
**данный механизм не используется в этой версии скрипта!!!**

# Логика работы
Скрипт опрашивает каталог заданный в параметре $SourceFolder (по умолчаению C:\MFAStatus\Status) и для всех найденных в нем CSV пытается выполнить следующие действия:
- считать построчно
- распарсить полученные данные в поля
- отправить в OMS Log Analytics

## Правила конвертации полей CSV в поля Log Analytics
Заданы внутри функции  function CSVtoJSON:
$Obj - конкретная строчка из CSV файла
Name REASON - имя поля в OMS Log Analytics. Дополнительно к полю будет добавлен символ _s при инжекте данных в облако

Текущая структура парсинга:
```
    $ScanResult | Add-Member -Type NoteProperty -Name REASON -Value $Obj.REASON 
    $ScanResult | Add-Member -Type NoteProperty -Name ISN -Value $Obj.ISN 
    $ScanResult | Add-Member -Type NoteProperty -Name AISUSERISN -Value $Obj.AISUSERISN 
    $ScanResult | Add-Member -Type NoteProperty -Name USERLOGIN -Value $Obj.USERLOGIN 
    $ScanResult | Add-Member -Type NoteProperty -Name USERCOMMENT -Value $Obj.USERCOMMENT
    $ScanResult | Add-Member -Type NoteProperty -Name CAUSE -Value $Obj.CAUSE 
    $ScanResult | Add-Member -Type NoteProperty -Name DATE -Value $Obj.DATE       
    $ScanResult | Add-Member -Type NoteProperty -Name Source -Value $CurrentFile     
```


# Примеры работы
Подробнее о языке запросов Log Analytics: https://docs.loganalytics.io/docs/Language-Reference

Скрипт создает класс Status2FA_CL. 

Вывести все данные за последний день
```
    Status2FA_CL
    | where TimeGenerated > ago(1d)
```
Вывести данные, с группировкой по комментарию
```
    Status2FA_CL
    | summarize count() by USERCOMMENT_s
    | order by count_ 
```

Вывести данные, с группировкой по причине
```
    Status2FA_CL
    | summarize count() by REASON_s
    | order by count_ 
```