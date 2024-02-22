### README for Juriba-BulkImport Module

---

#### Module Overview

The `Juriba-BulkImport` PowerShell module provides functions to efficiently import large datasets of device and user information into a Juriba Dashworks instance using bulk import methods. This module leverages the Juriba API to insert data from a `System.Data.DataTable` object, allowing for rapid data processing and importation.

---

#### Functions

- **Invoke-JuribaBulkImportDeviceFeedDataTable**: This function takes a DataTable containing device information and inserts the data into the specified Juriba Dashworks instance. It supports custom fields and allows for specifying batch sizes to optimize the import process.

- **Invoke-JuribaBulkImportUserFeedDataTable**: Similar to the device import function, this function is designed for user data. It processes a DataTable of user information for bulk import into Juriba Dashworks, supporting custom fields and batch processing.

---

#### Parameters

Both functions share similar parameters:

- **Instance**: The URI to the Juriba Dashworks instance.
- **APIKey**: An API key for authentication with the Dashworks instance.
- **ImportId** (Optional for UserFeed): The ID of the feed into which the data will be imported. If not specified, the FeedName must be provided to determine the feed.
- **JuribaDataTable**: A `System.Data.DataTable` object containing the data to be imported.
- **CustomFields** (Optional): An array of custom field names present in the DataTable.
- **BatchSize** (Optional): The number of records to be processed in each bulk import request.

---

#### Usage Example

```powershell
$deviceData = Get-YourDeviceDataFunction -As DataTable
$userData = Get-YourUserDataFunction -As DataTable

$paramsDevice = @{
    Instance = "https://your.dashworks.instance"
    JuribaDeviceDataTable = $deviceData
    APIKey = "your_api_key"
    ImportId = "your_device_feed_id"
    BatchSize = 1000
}

$paramsUser = @{
    Instance = "https://your.dashworks.instance"
    JuribaUserDataTable = $userData
    APIKey = "your_api_key"
    ImportId = "your_user_feed_id"
    BatchSize = 500
}

Invoke-JuribaBulkImportDeviceFeedDataTable @paramsDevice
Invoke-JuribaBulkImportUserFeedDataTable @paramsUser
```

---

#### Additional Notes

- Ensure your DataTables are correctly formatted with all required columns and custom fields defined.
- Adjust the `BatchSize` parameter based on your environment's performance and network capacity.
- Use the logging functions provided within the module to monitor the import process and handle any errors.

---

This module aims to streamline the process of integrating large datasets into Juriba Dashworks, making it an essential tool for administrators managing migrations or updates at scale.