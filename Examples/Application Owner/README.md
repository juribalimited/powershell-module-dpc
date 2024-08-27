# Send Apps to App Owner

The purpose of this script is to automate the process of exporting applications / users from DPC for use in Application Owner.

## Requirements

To be able to perform the export / import process you will require API keys for both DPC and AOM.

## Limits

The import process is limited to a maximum of 10,000 applications in a single batch.  If there are more than 10,000 applications in your DPC instance you will need to process them in batches.

If you only have a trial license for AOM then you are limited to a maximum of 100 users.  If an export / import process increases the user count to the limit then it will be aborted preventing any more applications being imported.

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
| InputBatchLimit | The number of applications to process | 0 | Must be >= 0 and no less than `InputBatchStartOffset` |
| OutputBatchLength | The maximum number of records sent in a single call to AOM | 10,000 | Must be between 1 & 10,000 |

#### Example Command Line
```
.\SendAppsToAppOwner.ps1 https://master.internal.juriba.com:8443 pCyty***** https://ao-uat.eu.juriba.app hoF7k***** 
```

N.B.  Errors are logged to the error stream so they can be captured to a file by redirecting std err.

```
.\SendAppsToAppOwner.ps1 https://master.internal.juriba.com:8443 pCyty***** https://ao-uat.eu.juriba.app hoF7k***** 2>err.log
```
