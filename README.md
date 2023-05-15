# Juriba Platform PowerShell Module

A PowerShell module which can be used to interact with the Juriba Platform API.

## Installation

### PowerShell Gallery

All modules are published on [PowerShell Gallery](https://www.powershellgallery.com/packages/Juriba.Platform/). Installing the module is as simple as:

```powershell
Install-Module Juriba.Platform
```

If you are updating from a previous version of the module simply run:

```powershell
Update-Module Juriba.Platform
```

## Usage

### Platform Instance

Before using the PowerShell cmdlets in this module you will need to know the URL for your Juriba Platform instance, specifically the base URL for the API. This URL is passed to all cmdlets using the -Instance parameter. For example:

```powershell
Get-DwImportDevice -Instance https://myplatforminstance.platform.juriba.app ...
```

To find the base URL for your instance of Platform:

1. Login to Platform and navigate to your User Profile using the link on the top right of the page.
1. Open the **API Keys** page.
1. Follow the link at the top of the page to the **API Documentation**.
1. Copy the URL for this page and remove "/apiv2/index.html" from the end. This is your API base URL.

**Note** that depending on your Juriba Platform configuration, your API base URL may or may not contain a port number.

### Authentication

Before using the PowerShell cmdlets in this module you will need to generate an API Key in Juriba Platform. This key is passed to all cmdlets using the -APIKey parameter. For example:

```powershell
Get-DwImportDevice -APIKey $apikey ...
```

We recommend storing API Keys securely using something like [Microsoft.PowerShell.SecretManagement](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.secretmanagement/?view=ps-modules).

For more information on using API Keys see [API Keys](https://docs.juriba.com/platform/next/platform-api/api-keys/get-api-key) in the Platform docs.

### Examples

The [Examples](./Examples) folder contains a number of examples demonstrating how each of the cmdlets can be used to work with data from various sources, such as MECM and Active Directory.

### Further Information

See [Import API](https://docs.juriba.com/platform/next/platform-api/import-api/overview) for more information about using the Data Import API endpoints.
