# Send Apps to App Owner

This script automates the process of exporting applications and users from DPC for use in Application Owner.

## Requirements

To perform the export/import process, you will need API keys for both DPC and AOM.

## Limits

The import process is limited to a maximum of 10,000 applications in a single batch. If there are more than 10,000 applications in your DPC instance, you will need to process them in multiple batches.

If you have a trial licence for AOM, you are restricted to 100 users during the trial. Your cannot run an import if it would cause your account to exceed this limit.

### Usage

The script `SendAppsToAppOwner.ps1` should be executed with the following mandatory parameters:

| Parameter | Description | Example Value |
|-----------|-------------|---------------|
| DpcInstance | The DPC instance to export from | https://master.internal.juriba.com:8443 |
| DpcApiKey | A valid API key for your DPC instance | pCyty***** |
| AomInstance | The AOM instance to import to | https://ao-uat.eu.juriba.app |
| AomApiKey | A valid API key for your AOM tenant | hoF7k***** |

The following optional parameters can also be provided:

| Parameter | Description | Default if not provided | Validation |
|-----------|-------------|-------------------------|------------|
| InputBatchLength | The maximum number of records returned in a single call to DPC | 10,000 | Must be between 1 & 10,000 |
| InputBatchStartOffset | The offset within the initial batch to start from, can be used to skip previously processed data | 0 | Must be >= 0 | 
| InputBatchLimit | The maximum number of applications to process, or 0 for all | 0 | Must be >= 0 |
| OutputBatchLength | The maximum number of records sent in a single call to AOM | 10,000 | Must be between 1 & 10,000 |

#### Example Command Line
```powershell
.\SendAppsToAppOwner.ps1 https://master.internal.juriba.com:8443 pCyty***** https://ao-uat.eu.juriba.app hoF7k***** 
```

Note: errors are logged to the error stream so they can be captured to a file if desired.

```powershell
.\SendAppsToAppOwner.ps1 https://master.internal.juriba.com:8443 pCyty***** https://ao-uat.eu.juriba.app hoF7k***** 2>err.log
```
