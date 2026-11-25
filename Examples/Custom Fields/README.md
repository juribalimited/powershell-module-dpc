# Copy custom fields between DPC instances

These scripts copy custom field definitions from one Juriba DPC instance to another, for example from Dev to Prod.

- `Export-JuribaCustomFields.ps1` reads custom field definitions from the source instance and saves them to a JSON file.
- `Import-JuribaCustomFields.ps1` compares that file with the target instance, shows what it will change, applies the changes and then checks the result.

## Requirements

- PowerShell 7 or later.
- `Juriba.DPC` 1.1.20.0 or later. We recommend the latest version: `Install-Module Juriba.DPC` or `Update-Module Juriba.DPC`.
- An API key for each instance. The key for the target instance needs administrator rights to create and update custom fields.

## Before you run them against production

These are example scripts. Read them and try them out before using them on a production instance.

- **Try them on a test instance first.** Import into a test or staging instance and check the result in the DPC UI.
- **Start small.** Use `-NameLike` on the export to copy one or two fields first.
- **Always preview with `-WhatIf`** and read the plan before running the import for real.
- **Take a snapshot of the target first.** Run the export against the target before importing. The import has no undo. The snapshot is your record of how the target looked, and any field the import created can be removed with `Remove-JuribaCustomField`.
- **Keep `-UpdateExisting` for when you need it.** Without it, the import only creates new fields and never changes existing ones.

The import never deletes custom fields and never changes the value type of an existing field.

## What gets copied

For each field: name, CSV column header, value type, object types (Device / User / Application / Mailbox), active state, update source (Directly / ETL) and the external update setting.

## Usage

```powershell
# 0. Snapshot the target as it is now, for reference
.\Export-JuribaCustomFields.ps1 -Instance "https://prod.dpc.juriba.app" -APIKey "xxxxx" -OutputPath .\prod-before.json

# 1. Export from the source
.\Export-JuribaCustomFields.ps1 -Instance "https://dev.dpc.juriba.app" -APIKey "xxxxx" -OutputPath .\customfields.json

# 2. Preview the changes on the target. Nothing is changed.
.\Import-JuribaCustomFields.ps1 -Instance "https://prod.dpc.juriba.app" -APIKey "xxxxx" -InputPath .\customfields.json -WhatIf

# 3. Import, and keep a CSV report
.\Import-JuribaCustomFields.ps1 -Instance "https://prod.dpc.juriba.app" -APIKey "xxxxx" -InputPath .\customfields.json -ReportPath .\import-report.csv
```

### Export parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| Instance | Yes | The DPC instance to export from |
| APIKey | Yes | API key for the instance |
| OutputPath | Yes | Path of the JSON file to write |
| NameLike | No | Only export custom fields whose name matches this wildcard pattern. Defaults to all fields. |

### Import parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| Instance | Yes | The DPC instance to import into |
| APIKey | Yes | API key for the instance |
| InputPath | Yes | JSON file created by `Export-JuribaCustomFields.ps1` |
| UpdateExisting | No | Update existing fields whose settings differ from the export. Without this switch the differences are only reported. |
| ReportPath | No | Path of a CSV report listing each field, the action taken and the validation result |
| WhatIf | No | Show what would change without changing anything |

## How the import handles each field

Fields are matched on CSV column header, because DPC requires it to be unique. Names don't have to be unique.

| Action | When | What happens |
|--------|------|--------------|
| Create | No field on the target uses the CSV column header | The field is created |
| Unchanged | The field exists with the same settings | Nothing |
| Update | The field exists but some settings differ | The differences are listed. They are only applied with `-UpdateExisting`. |
| Conflict | The value type differs, or the name is already used by a field with a different CSV column header | Listed and left alone. Changing the type of a field that already holds data isn't safe. |

After importing, every exported field is read back from the target and compared setting by setting. The script prints a pass/fail count, and writes the CSV report if `-ReportPath` was used. The import is safe to run more than once; a second run makes no changes.

## Limits

- **Custom field ids differ between instances.** Each instance assigns its own ids. Lists refer to custom fields by id, and dashboard widgets and automations refer to lists, so they can't be copied between instances as they are. Recreate them on the target after importing the fields. If your own scripts refer to a custom field by id, look it up by CSV column header instead, since the import keeps headers the same.
- **Display order isn't copied.** New fields are added after the target's existing fields.
- **Only definitions are copied,** not the values held on devices, users, applications or mailboxes.
