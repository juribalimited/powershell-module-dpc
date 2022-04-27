# Dashworks API PowerShell Module

> **Warning** - This module is under active development

## About

A PowerShell module which can be used to interact with the Dashworks API.

## Installation

### PowerShell Gallery

All modules are published on [PowerShell Gallery](https://www.powershellgallery.com/packages/Juriba.Dashworks/). Installing the module is as simple as:

```powershell
Install-Module Juriba.Dashworks
```

If you are updating from a previous version of the module simply run:

```powershell
Update-Module Juriba.Dashworks
```

## Usage

### Dashworks Instance

Before using the PowerShell cmdlets in this module you will need to know the URL for your Dashworks instance, specifically the base URL for the API. This key is passed to all cmdlets using the -Instance parameter. For example:

```powershell
Get-DwImportDevice -Instance https://mydashworksinstance.dashworks.juriba.app ...
```

To find the base URL for your instance of Dashworks:

1. Login to Dashworks and navigate to your User Profile using the link on the top right of the page.
1. Open the **API Keys** page.
1. Follow the link at the top of the page to the **API Documentation**.
1. Copy the URL for this page and remove "/apiv2/index.html" from the end. This is your API base URL.

**Note** that depending on your Dashworks configuration, your API base URL may or may not contain a port number.

### Authentication

Before using the PowerShell cmdlets in this module you will need to generate an API Key in Dashworks. This key is passed to all cmdlets using the -APIKey parameter. For example:

```powershell
Get-DwImportDevice -APIKey $apikey ...
```

We recommend storing API Keys securely using something like [Microsoft.PowerShell.SecretManagement](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.secretmanagement/?view=ps-modules).

For more information on using API Keys see [API Keys](https://docs.juriba.com/dashworks/dashworks-api/api-keys/get-api-key) in the Dashworks docs.

### Examples

The [Examples](./Examples) folder contains a number of examples demonstrating how each of the cmdlets can be used to work with data from various sources, such as MECM and Active Directory.

More documentation for each example can be found in the [Dashworks API docs](https://docs.juriba.com/dashworks/dashworks-api/data-import-examples).
