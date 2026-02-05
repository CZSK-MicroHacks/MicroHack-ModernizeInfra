# .NET 10.0 Upgrade Plan

## Execution Steps

Execute steps below sequentially one by one in the order they are listed.

1. Validate that a .NET 10.0 SDK required for this upgrade is installed on the machine and if not, help to get it installed.
2. Ensure that the SDK version specified in global.json files is compatible with the .NET 10.0 upgrade.
3. Upgrade ModernizeInfraApp\ModernizeInfraApp.csproj

## Settings

This section contains settings and data used by execution steps.

### Excluded projects

No projects are excluded from this upgrade.

### Aggregate NuGet packages modifications across all projects

NuGet packages used across all selected projects or their dependencies that need version update in projects that reference them.

| Package Name                              | Current Version | New Version | Description                      |
|:------------------------------------------|:---------------:|:-----------:|:---------------------------------|
| Microsoft.EntityFrameworkCore.SqlServer   | 6.0.33          | 10.0.2      | Recommended for .NET 10.0        |

### Project upgrade details

This section contains details about each project upgrade and modifications that need to be done in the project.

#### ModernizeInfraApp\ModernizeInfraApp.csproj modifications

Project properties changes:
  - Target framework should be changed from `net6.0` to `net10.0`

NuGet packages changes:
  - Microsoft.EntityFrameworkCore.SqlServer should be updated from `6.0.33` to `10.0.2` (*recommended for .NET 10.0*)
