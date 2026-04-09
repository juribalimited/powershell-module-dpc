# CLAUDE.md - Juriba.DPC PowerShell Module

## Project Overview

PowerShell module (`Juriba.DPC`) for interacting with the Juriba DPC API. Published to the PowerShell Gallery automatically on merge to `main`. There is also a `Juriba.DPC.ServiceNow` module which is not yet published and should be ignored unless explicitly asked about.

## Project Structure

```
Juriba.DPC/
  Public/          - Exported functions (one function per file)
  Private/         - Internal helper functions (not exported)
  Juriba.DPC.psm1  - Root module (dot-sources Public/ and Private/, exports Public)
  Juriba.DPC.psd1  - Module manifest (version, exports list, metadata)
Examples/            - Example scripts organized by integration type
.github/workflows/
  checks.yaml      - PR validation: PSScriptAnalyzer
  publish.yaml     - Auto-publish to PowerShell Gallery on merge to main
```

## CI/CD

- **PR checks**: PSScriptAnalyzer runs on PRs touching `Juriba.DPC/**` with `-EnableExit`. This means **all** findings fail the build, including Information-level (not just warnings/errors). Excluded rule: `PSAvoidTrailingWhitespace`.
- **Publishing**: On push to `main` with changes in `Juriba.DPC/**`, the module is published to the PowerShell Gallery via `Publish-Module`.
- Run PSScriptAnalyzer locally before committing: `Invoke-ScriptAnalyzer -Path .\Juriba.DPC -Recurse -EnableExit -ExcludeRule PSAvoidTrailingWhitespace`
- Common pitfall: if a function returns different types depending on code path (e.g., a string in one branch, a PSObject in another), add `[OutputType([String])]` or the appropriate types to avoid `PSUseOutputTypeCorrectly` findings.

## Adding a New Function

1. Create a `.ps1` file in `Juriba.DPC\Public\` named exactly after the function.
2. Add the function name to the `FunctionsToExport` array in `Juriba.DPC.psd1` (alphabetical within its verb group).
3. Increment `ModuleVersion` in `Juriba.DPC.psd1`.

## Function Naming

- Pattern: `[Verb]-Juriba[Entity]` (e.g., `Get-JuribaTeam`, `New-JuribaImportDevice`)
- Use approved PowerShell verbs: `Get`, `New`, `Set`, `Remove`, `Add`, `Connect`, `Disconnect`, `Invoke`, `Export`, `Start`, `Stop`, `Update`
- Existing functions have a legacy `Dw` alias from when the module was named `Juriba.Dashworks` (e.g., `[alias("Get-DwTeam")]`). New functions do not need an alias.

## Function Template

Follow this structure for all new functions:

```powershell
#requires -Version 7
function Verb-JuribaEntity {
    <#
        .SYNOPSIS
        Short one-line description.

        .DESCRIPTION
        Longer description including which API version is used.

        .PARAMETER Instance
        Optional. Dashworks instance to be provided if not authenticating using Connect-Juriba. For example, https://myinstance.dashworks.app:8443

        .PARAMETER APIKey
        Optional. API key to be provided if not authenticating using Connect-Juriba.

        .PARAMETER ExampleParam
        Description of the parameter.

        .OUTPUTS
        Description of what is returned.

        .EXAMPLE
        PS> Verb-JuribaEntity @DwParams -ExampleParam "value"
    #>
    [CmdletBinding(SupportsShouldProcess)]  # Include SupportsShouldProcess for New/Set/Remove functions
    param(
        [Parameter(Mandatory=$false)]
        [string]$Instance,
        [Parameter(Mandatory=$false)]
        [string]$APIKey,
        [Parameter(Mandatory=$true)]
        [string]$ExampleParam
    )

    if ((Get-Variable 'dwConnection' -Scope 'Global' -ErrorAction 'Ignore') -and !$APIKey -and !$Instance) {
        $APIKey = ConvertFrom-SecureString -SecureString $dwConnection.secureAPIKey -AsPlainText
        $Instance = $dwConnection.instance
    }

    if ($APIKey -and $Instance) {
        $uri = "{0}/apiv2/endpoint" -f $Instance
        $headers = @{'x-api-key' = $APIKey}

        try {
            if ($PSCmdlet.ShouldProcess($ExampleParam)) {
                $result = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
                return $result
            }
        }
        catch {
            Write-Error $_
        }
    } else {
        Write-Error "No connection found. Please ensure `$APIKey and `$Instance is provided or connect using Connect-Juriba before proceeding."
    }
}
```

## Key Patterns

### Authentication
- `$Instance` and `$APIKey` are always optional parameters (listed first).
- Functions must check for the global `$dwConnection` object set by `Connect-Juriba` as a fallback.
- The connection check block is identical across all functions (see template above).

### API Calls
- Construct URIs with string formatting: `"{0}/apiv2/endpoint/{1}" -f $Instance, $Id`
- Headers: `@{'x-api-key' = $APIKey}`
- Use `Invoke-RestMethod` for newer functions (apiv2). Older functions may use `Invoke-WebRequest` with manual `ConvertFrom-Json`.
- JSON body: build a hashtable, pipe to `ConvertTo-Json`, encode with `[System.Text.Encoding]::UTF8.GetBytes()` for POST/PUT/PATCH.
- Content type: `"application/json"`
- URL-encode filter parameters: `[System.Web.HttpUtility]::UrlEncode("eq(name,'{0}')" -f $Name)`

### API Version Compatibility
Some functions check the DPC version and use different endpoints:
```powershell
$ver = Get-JuribaDPCVersion -Instance $Instance -MinimumVersion "5.14"
if ($ver) {
    $uri = "{0}/apiv2/imports/{1}" -f $Instance, $ImportId     # 5.14+
} else {
    $uri = "{0}/apiv2/imports/devices/{1}" -f $Instance, $ImportId  # older
}
```

### Error Handling
- Wrap API calls in `try`/`catch` with `Write-Error $_`.
- For specific HTTP status codes (e.g., 409 conflict), provide a descriptive error message.
- Validate required inputs early with `throw` for logic errors.

### ShouldProcess
- All mutating functions (`New-`, `Set-`, `Remove-`) must use `[CmdletBinding(SupportsShouldProcess)]`.
- Wrap the API call: `if ($PSCmdlet.ShouldProcess($IdentifyingValue)) { ... }`
- `Get-` functions do not need ShouldProcess.

### Parameter Sets
- Use `DefaultParameterSetName` when a function supports mutually exclusive lookup methods (e.g., by Id vs. by Name).
- Mark each exclusive parameter with its `ParameterSetName`.

### PSScriptAnalyzer Suppressions
- Use `[Diagnostics.CodeAnalysis.SuppressMessageAttribute("RuleName", "")]` when necessary (e.g., `PSAvoidGlobalVars` in `Connect-Juriba`).

## Code Style

- 4-space indentation
- Opening braces on the same line as the statement
- `$camelCase` for local variables
- `$PascalCase` for parameters
- String formatting with `-f` operator (not string interpolation) for URI construction
- Comment-based help inside the function, after the alias declaration
- One function per file, filename matches function name exactly
