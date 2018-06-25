# О скрипте Report2FA.ps1
Данный скрипт (вместе с OMSDataCollector.ps1) предназначен для отправки отчетов о результатах сработки MFA для определенных пользователей в Microsoft OMS (Log Analytics). Интеграция отчетов с OMS позволяет получить удобный, полезный и красивый механизм обработки данных об состоянии MFA. 
Кроме того, данный скрипт может быть использован как пример работы по загрузке CSV файлов в OMS Log Analytics с разбором по полям. 
**Внимание**
Не забудьте поменять переменные в скрипте!!!

# Предварительные требования
Для передачи CSV файлов в Microsoft OMS (Log Analytics) вам необходимо:
- пространство Microsoft Log Analytics
- файлы CSV в кодировке UTF-8, с разделителем ; Если у вас другие параметры файла, не забудьте поменять это в скрпте
- скрипт [Report2FA.ps1](https://github.com/altaranenco/OMS/blob/master/CSV/Report2FA.ps1) и [OMSDataCollector.ps1](https://github.com/altaranenco/OMS/blob/master/OMSDataCollector.ps1) должны находить в одной папке, например C:\MFAStatus\
- доступ в интернет к серверам OMS\Log Analytics по 443 порту, с сервера на котором будут запускаться скрипты PowerShell
- вручную созданная структура каталогов для работы, подробнее об этом ниже

# Настройка скрипта Status2FA.ps1 перед первым использованием
## ID пространства и ключ
Log Analytics Workplace ID и ключ задаются переменными: $CustomerId и $SharedKey в шапке скрипта Report2FA.ps1

## Структура каталогов 
Для правильной работы скрипта необходимо предварительно **вручную** создать структуру каталогов:
**C:\MFAStatus** - корневая директория скрипта. В корне должны быть расположены файлы Report2FA.ps1 и OMSDataCollector.ps1. Если вы используете другую директорую, не C:\MFAStatus не забудьте в скрипте поменять значение переменной $RootFolder="C:\MFAStatus\", и обновить дот-ссылку на файл OMSDataCollector.ps1. Между знаком . (точка) и именем файла должно быть 2 знака пробела: ".  C:\MFAStatus\OMSDataCollector.ps1"

**C:\MFAStatus\Reports** - базовый каталог для оригинальных CSVс реестром MFA. Можно указать сетевой ресурс в качестве источника данных. В скрипте задается переменной $SourceFolder

**C:\MFAStatus\Arch** - каталог, в который скрипт будет перекладывать файлы после обработки. Например в каталоге C:\MFAStatus\Reports\report.csv. После обработки и выгрузки данных в OMS Log Analytics, файл переносится в каталог C:\MFAStatus\Arch и переименовывается в 20180601 report.csv

**C:\MFAStatus\Log** - каталог, в котором будет храниться журнал работы скрипта

**C:\MFAStatus\JSON** - каталог для хранения обработанных CSV, которые сконвертированные в JSON для отправки в OMS. Если для отчета CSV уже существует соответсвующий файл JSON, то повторная обработка CSV проводиться не будет. JSON будет отправлен в OMS как есть. 
**данный механизм не используется в этой версии скрипта!!!**

# Логика работы
Скрипт опрашивает каталог заданный в параметре $SourceFolder (по умолчаению C:\MFAStatus\Reports) и для всех найденных в нем CSV пытается выполнить следующие действия:
- считать построчно
- распарсить полученные данные в поля
- отправить в OMS Log Analytics
- перенести файл в архивную папку

## Правила конвертации полей CSV в поля Log Analytics
Заданы внутри функции  function CSVtoJSON:
$ROW - конкретная строчка из CSV файла
Name Result - имя поля в OMS Log Analytics. Дополнительно к полю будет добавлен символ _s при инжекте данных в облако

Текущая структура парсинга:
```
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
```

# Примеры работы
Подробнее о языке запросов Log Analytics: https://docs.loganalytics.io/docs/Language-Reference

Скрипт создает класс Status2FA_CL. 

Вывести все данные за последний день
```
    IngosMFA_CL
    | where TimeGenerated > ago(1d)
```
Вывести данные, с группировкой по IP адресам
```
    IngosMFA_CL
    | summarize count() by IP_s
    | order by count_ 
```

Вывести список пользователей, с 1 IP адреса. Группировку делать на временном промежутке 1 час
```
    IngosMFA_CL
    | summarize count(Account_s), makeset(Account_s) by IP_s, bin(TimeGenerated, 1h)
    | order by count_Account_s 
```