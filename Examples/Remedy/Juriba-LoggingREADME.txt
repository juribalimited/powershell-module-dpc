README.TXT for Juriba Logging PowerShell Module
=================================================

Overview
---------
This PowerShell module is designed to facilitate logging and integration with the Juriba Dashworks platform. It provides functions for creating log entries, managing log files, and interfacing with the Juriba API for event logging.

The module includes capabilities for appending log entries to local files, optional console output, managing log file retention, and sending log messages to the Juriba Dashworks platform.

Prerequisites
--------------
- PowerShell 5.1 or later
- Access to a Juriba Dashworks instance
- An API key for the Juriba Dashworks instance

Installation
-------------
1. Copy the PowerShell script file (.psm1) to a directory of your choice.
2. Import the module into your PowerShell session using `Import-Module <path-to-the-script>`.

Usage
------
The module provides the following primary functions:
- `Add-LogEntry`: Appends a log entry to a specified log file and optionally to the console.
- `Remove-OldLogFiles`: Deletes log files older than a specified number of days.
- `Start-JuribaLog`: Initiates logging to the Juriba Dashworks platform.
- `Add-JuribaLogMessage`: Sends a log message to the Juriba Dashworks platform.
- `Close-JuribaLog`: Ends logging to the Juriba Dashworks platform.

To use these functions, first import the module into your PowerShell session. Then, you can call the functions as needed in your scripts or from the command line.

Examples
---------
### Starting Juriba Logging
```powershell
Start-JuribaLog -Instance "https://your-juriba-instance" -APIKey "your-api-key"

Add Log Entry:
Add-LogEntry -Entry "This is a log message" -WriteToConsole $true -JuribaLogLevel "Info" -SendToJuriba $true

Removing Old Log File
Remove-OldLogFiles -LogDirectory "C:\Logs" -DaysToKeepLogs 7


Closing Juriba Logging
Close-JuribaLog -Instance "https://your-juriba-instance" -APIKey "your-api-key"

