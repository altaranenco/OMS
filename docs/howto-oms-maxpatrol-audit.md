# О скрипте MaxPatrolXMLtoJSON.ps1
Данный скрипт (вместе с OMSDataCollector.ps1) предназначен для отправки отчетов MaxPatrol в Microsoft OMS (Log Analytics). Интеграция отчетов MaxPatrol с OMS позволяет получить удобный, полезный и красивый механизм обработки данных об уязвимостях найденных с помощью MaxPatrol. 

![alt-Внутренности дашборда, с информацией об уязвимостях](https://github.com/altaranenco/OMS/blob/master/docs/vulnerability_04.PNG "Внутренности дашборда, с информацией об уязвимостях")

# Предварительные требования
Для интеграции отчетов MaxPatrol в Microsoft OMS (Log Analytics) вам необходимо:
- пространство Microsoft Log Analytics
- отчеты MaxPatrol в режиме аудита, в формате XML
- скрипт [MaxPatrolXMLtoJSON_v2.ps1](https://github.com/altaranenco/OMS/blob/master/MaxPatrol/MaxPatrol_Pentest_XMLtoJSON_v2.ps1) и [OMSDataCollector.ps1](https://github.com/altaranenco/OMS/blob/master/OMSDataCollector.ps1) должны находить в одной папке, например C:\MaxPatrol_Reports
- доступ в интернет к серверам OMS\Log Analytics по 443 порту, с сервера на котором будут запускаться скрипты PowerShell
- вручную созданная структура каталогов для работы, подробнее об этом ниже

# Влияние на биллинг Log Analytics
При конвертировании из MaxPatrol XML в OMS Log Analytics происходит существенная отчистка данных от излишней информации. По моему опыту, стоит ориентироваться на сжание 10 к 1, т.е. для XML размером 250Мб полезный объем данных отправляемый в облако составит порялка 25Мб. 

Важное влияние на стоимость Log Analytics заключается в модели лицензирования per Node или per GB. Если вы создавали свою Azure Subscription после мая 2018 года, то скорее всего у вас принудительно установлен тип цен per GB. По умолчанию, скрипты ориентируются именно на новую модель ценообразования OMS (per GB 2018). В таком случае, вы оплачиваете только объем загруженных данных. Если же, у вас используется модель с оплатой по агентски\за узел (per node), скрипт может дать негативный эффект с точки зрения затрат на Log Analytics. В таком случае (per Node), установите параметр скрипта в модель 


# Настройка MaxPatrol
MaxPatrol должен быть настроен на автоматическую генерацию отчетов в формате XML. Сгенерированные отчеты необходимо выкладывать в папку \*C:\MaxPatrol_Reports\XML\*. Удобнее всего размещать эту папку например на сервере OMS Gateway, поскольку с него уже открыт доступ к облаку Microsoft
Если вы хотите разместить файлы скрипта в другом каталоге, не забудьте изменить это в параметрах скрипта:
    $MaxPatrolFolder="C:\MaxPatrol_Reports\XML\"
    $MaxPatrolArch="C:\MaxPatrol_Reports\Arch\"
    $LogFolder="C:\MaxPatrol_Reports\Log\"
    $JSONFolder="C:\MaxPatrol_Reports\JSON\"

## Структура каталогов C:\MaxPatrol_Reports
Для правльной работы скрипта необходимо предварительно вручную создать структуру каталогов:

**C:\MaxPatrol_Reports\XML** - базовый каталог для оригинальных XML от MaxPatrol с вашими результатами сканирования. Можно расшарить по сети, чтобы MaxPatrol выкладывал отчеты по сети, автоматически

**C:\MaxPatrol_Reports\Arch** - каталог, в который скрипт будет перекладывать устаревшие отчеты MaxPatrol. Например в каталоге C:\MaxPatrol_Reports\XML\ одновременно расположены два файла: 
- Отчет Аудит - Серверы 02.04.2018 00-31-01.xml 
- Отчет Аудит - Серверы 03.04.2018 00-31-00.xml

при запуске скрипта, файл Отчет Аудит - Серверы 02.04.2018 00-31-01.xml будет перемещен в каталог C:\MaxPatrol_Reports\Arch\ без обработки

**C:\MaxPatrol_Reports\Log** - каталог, в котором будет храниться журнал работы скрипта

**C:\MaxPatrol_Reports\JSON** - каталог для хранения обработанных XML, которые сконвертированные в JSON для отправки в OMS. Если для отчета XML уже существует соответсвующий файл JSON, то повторная обработка XML проводиться не будет. JSON будет отправлен в OMS как есть. Подробнее о преобразовании MaxPatrol XML в JSON ниже в соответствующем разделе.

## Рекомендации по созданию отчетов MaxPatrol
Практика показала, что лучше всего разбивать задания сканирования  MaxPatrol на несколько отдельных циклов, например:
- сервера ЦО
- сервера по регионам
- рабочие станции ЦО
- критические рабочие стации
- рабочие станции по регионам

Такой подход позволяет во-первых использовать для каждого элемента инфраструктуры свой собственный цикл сканирования, а во-вторых, уменьшает размер итогового XML отчета.

Скрипт поддерживает работу только со следующими параметрами формирования XML отчета
![alt-Настройки MaxPatrol для генерации XML отчетов](https://raw.githubusercontent.com/altaranenco/OMS/master/docs/maxpatrol_settings.png "Настройки MaxPatrol для генерации XML отчетов")

# Базовые дашборды Log Analytics
В Log Analytics вы можете создавать свои собственные дашборды, подробнее: https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-view-designer

[Скачать Dashboard](https://github.com/altaranenco/OMS/blob/master/MaxPatrol/Vulnerability.omsview)

## Overview tile dasboard

![alt-Стартовый тайл, с информацией об уязвимостях](https://github.com/altaranenco/OMS/blob/master/docs/vulnerability_01.PNG "Стартовый тайл, с информацией об уязвимостях")

## View dashboard

![alt-Внутренности дашборда, с информацией об уязвимостях](https://github.com/altaranenco/OMS/blob/master/docs/vulnerability_04.PNG "Внутренности дашборда, с информацией об уязвимостях")

# Примеры работы
Скрипт создает класс Vulner_CL. ![alt-Пример данных MaxPatrol в OMS](https://github.com/altaranenco/OMS/blob/master/docs/vulnerability_03.PNG "Пример данных MaxPatrol в OMS")

Вывести все узявимости за последний день, сгрупировав по важности
```
    Vulner_CL
    | where TimeGenerated > ago(1d)
    | summarize count() by Level_s
```

