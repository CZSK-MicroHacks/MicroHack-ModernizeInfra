# Automated Deployment Guide

This document explains how the automated deployment system works for the ModernizeInfraApp application.

## Overview

The automated deployment system consists of three main components:

1. **GitHub Actions Workflows** - Automatically build and package the application
2. **Deployment Scripts** - PowerShell scripts to deploy updates to the VM
3. **Optional Scheduled Updates** - Windows scheduled tasks for automatic updates

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                         │
│                                                                  │
│  Code Change → GitHub Actions → Build → Publish → Release       │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               │ app-binaries.zip
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                       GitHub Releases                            │
│                                                                  │
│  Latest Release: app-binaries.zip                               │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               │ Download & Deploy
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Azure VM                                 │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  Manual Deployment:                                     │   │
│  │  - Run update-application.ps1                          │   │
│  │                                                         │   │
│  │  Automatic Deployment (Optional):                      │   │
│  │  - Scheduled Task runs daily at 2 AM                   │   │
│  │  - Checks for new releases                             │   │
│  │  - Downloads and deploys automatically                 │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Application: C:\Apps\ModernizeInfraApp                        │
│  Port: 8080                                                     │
└─────────────────────────────────────────────────────────────────┘
```

## GitHub Actions Workflows

### 1. Build Application Workflow (`build-app.yml`)

**Trigger:** Pushes to `main` branch or manual dispatch

**What it does:**
1. Builds the .NET application
2. Runs tests (if any)
3. Publishes the application
4. Creates a deployment package (`app-binaries.zip`)
5. Creates a GitHub Release with the package

**Usage:**
- Automatically runs on every push to main that modifies files in `ModernizeInfraApp/`
- Can be manually triggered from GitHub Actions tab

### 2. Full Deployment Workflow (`deploy-app.yml`)

**Trigger:** Pushes to `main` branch or manual dispatch

**What it does:**
1. Builds and packages the application (same as above)
2. Optionally deploys directly to Azure VM using Azure credentials

**Requirements:**
- Azure credentials stored in GitHub Secrets:
  - `AZURE_CREDENTIALS` - Service principal credentials
  - `AZURE_RESOURCE_GROUP` - Resource group name
  - `AZURE_VM_NAME` - VM name

**Note:** This workflow is optional. If Azure credentials are not configured, the workflow will only build and create releases.

## Deployment Methods

### Method 1: Manual Deployment (Recommended for Hackathon)

**On the Azure VM:**

1. Open PowerShell as Administrator
2. Run the update script:
   ```powershell
   cd C:\Apps\ModernizeInfraApp
   .\update-application.ps1
   ```

**What the script does:**
- Fetches the latest release from GitHub
- Downloads `app-binaries.zip`
- Stops the running application
- Backs up the current version
- Extracts the new version
- Optionally starts the application

**Benefits:**
- Simple and manual control
- No Azure credentials required
- Works immediately after setup

### Method 2: Scheduled Automatic Updates

**Setup (one-time):**

1. Open PowerShell as Administrator on the VM
2. Run the setup script:
   ```powershell
   cd C:\Apps\ModernizeInfraApp
   .\setup-auto-update.ps1
   ```

**What it does:**
- Creates a Windows Scheduled Task
- Runs daily at 2:00 AM
- Automatically checks for and deploys updates

**Benefits:**
- Fully automated
- No manual intervention needed
- Perfect for long-running scenarios

**Management:**
```powershell
# Run update immediately
Start-ScheduledTask -TaskName "ModernizeInfraApp-AutoUpdate"

# View task status
Get-ScheduledTask -TaskName "ModernizeInfraApp-AutoUpdate"

# Disable automatic updates
Disable-ScheduledTask -TaskName "ModernizeInfraApp-AutoUpdate"

# Remove automatic updates
Unregister-ScheduledTask -TaskName "ModernizeInfraApp-AutoUpdate"
```

### Method 3: Azure VM Run Command (CI/CD)

**For advanced scenarios with Azure integration:**

If you have Azure credentials configured in GitHub Secrets, the `deploy-app.yml` workflow can automatically deploy to the VM using Azure VM Run Command.

**Setup:**
1. Create an Azure Service Principal
2. Add GitHub Secrets:
   - `AZURE_CREDENTIALS`
   - `AZURE_RESOURCE_GROUP`
   - `AZURE_VM_NAME`

**Benefits:**
- Fully automated CI/CD pipeline
- Deploys immediately after code changes
- Enterprise-grade deployment

## Deployment Script Details

### `update-application.ps1`

**Purpose:** Manual or scheduled application updates

**Features:**
- Fetches latest release from GitHub API
- Version tracking to avoid redundant updates
- Automatic backup of previous version
- Rollback capability if deployment fails
- Interactive prompts for manual use
- Silent mode for scheduled tasks

**Location:** `C:\Apps\ModernizeInfraApp\update-application.ps1`

**Requirements:**
- Internet connectivity
- Administrator privileges
- .NET Runtime installed

### `setup-auto-update.ps1`

**Purpose:** Configure automatic updates

**Features:**
- Downloads the latest `update-application.ps1` script
- Creates Windows Scheduled Task
- Configures daily updates at 2 AM
- Can be run multiple times (recreates task)

**Location:** `C:\Apps\ModernizeInfraApp\setup-auto-update.ps1`

**Requirements:**
- Administrator privileges
- Task Scheduler service running

## Troubleshooting

### Build fails in GitHub Actions

**Symptoms:** Workflow shows red X, build errors

**Solutions:**
1. Check the workflow logs in GitHub Actions tab
2. Ensure code compiles locally: `dotnet build`
3. Check .NET version compatibility

### Cannot download from GitHub

**Symptoms:** "Failed to fetch latest release"

**Solutions:**
1. Check internet connectivity on VM
2. Verify GitHub is accessible: `Test-NetConnection raw.githubusercontent.com -Port 443`
3. Check firewall settings

### Application doesn't start after update

**Symptoms:** Deployment succeeds but app doesn't run

**Solutions:**
1. Check if .NET runtime is installed: `dotnet --version`
2. Check database connectivity (SQL Server must be running)
3. Review appsettings.json for correct connection strings
4. Check application logs

### Scheduled task not running

**Symptoms:** No automatic updates occurring

**Solutions:**
1. Verify task exists: `Get-ScheduledTask -TaskName "ModernizeInfraApp-AutoUpdate"`
2. Check task history in Task Scheduler
3. Ensure VM is running at scheduled time
4. Run task manually to test: `Start-ScheduledTask -TaskName "ModernizeInfraApp-AutoUpdate"`

## Testing the Deployment

### Test Manual Deployment

1. Make a small change to the application code
2. Push to main branch
3. Wait for GitHub Actions to complete (2-3 minutes)
4. On VM, run: `.\update-application.ps1`
5. Verify new version is deployed
6. Test application: `http://localhost:8080/api/customers`

### Test Automatic Updates

1. Setup automatic updates: `.\setup-auto-update.ps1`
2. Run task immediately: `Start-ScheduledTask -TaskName "ModernizeInfraApp-AutoUpdate"`
3. Check task history in Task Scheduler
4. Verify application is updated

## Best Practices

1. **Always test locally** before pushing to main
2. **Use feature branches** for development
3. **Monitor GitHub Actions** for build failures
4. **Keep backups** - update script automatically creates them
5. **Version tracking** - check `version.txt` in app folder
6. **Review logs** - check deployment logs after updates
7. **Test after deployment** - verify application works

## Security Considerations

1. **GitHub Releases are public** - anyone can download binaries
2. **Use HTTPS** for all downloads
3. **Scheduled tasks run as SYSTEM** - ensure scripts are trusted
4. **Azure credentials** - never commit to repository
5. **Backup management** - old backups consume disk space

## Configuration Files

### GitHub Workflows Location
- `.github/workflows/build-app.yml` - Build and release workflow
- `.github/workflows/deploy-app.yml` - Build and deploy workflow

### Deployment Scripts Location
- `init-vm/scripts/update-application.ps1` - Update script
- `init-vm/scripts/setup-auto-update.ps1` - Auto-update setup
- `init-vm/scripts/deploy-application.ps1` - Initial deployment

### VM Application Location
- Application: `C:\Apps\ModernizeInfraApp`
- Configuration: `C:\Apps\ModernizeInfraApp\appsettings.json`
- Version tracking: `C:\Apps\ModernizeInfraApp\version.txt`
- Backups: `C:\Apps\ModernizeInfraApp.backup.*`

## Support

For issues or questions:
1. Check this documentation
2. Review troubleshooting section
3. Check GitHub Actions logs
4. Review VM deployment logs
5. Contact hackathon organizers

## License

This deployment system is for educational purposes as part of the CZ/SK MicroHack program.
