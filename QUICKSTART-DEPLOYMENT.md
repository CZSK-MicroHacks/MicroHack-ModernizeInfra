# Quick Start: Automated Deployment

This guide shows how to quickly set up and use the automated deployment system.

## Prerequisites

- Azure VM deployed using `init-vm/deploy-vm.sh`
- SQL Server installed on VM
- Internet connectivity

## Option 1: Manual Updates (Simplest)

**On your VM:**

1. Open PowerShell as Administrator
2. Navigate to the application folder:
   ```powershell
   cd C:\Apps\ModernizeInfraApp
   ```
3. Run the update script:
   ```powershell
   .\update-application.ps1
   ```
4. Follow the prompts to deploy the latest version
5. Start the application when prompted

**That's it!** The script will:
- Download the latest release from GitHub
- Backup your current version
- Deploy the new version
- Optionally start the application

## Option 2: Automatic Updates (Set and Forget)

**One-time setup on your VM:**

1. Open PowerShell as Administrator
2. Navigate to the application folder:
   ```powershell
   cd C:\Apps\ModernizeInfraApp
   ```
3. Run the setup script:
   ```powershell
   .\setup-auto-update.ps1
   ```
4. Confirm the setup

**Done!** Your application will now automatically update every day at 2 AM.

### Managing Automatic Updates

Run update immediately:
```powershell
Start-ScheduledTask -TaskName "ModernizeInfraApp-AutoUpdate"
```

Disable automatic updates:
```powershell
Disable-ScheduledTask -TaskName "ModernizeInfraApp-AutoUpdate"
```

Remove automatic updates:
```powershell
Unregister-ScheduledTask -TaskName "ModernizeInfraApp-AutoUpdate"
```

## How It Works

1. **Developer** pushes code changes to the `main` branch
2. **GitHub Actions** automatically builds and tests the application
3. **GitHub Releases** publishes `app-binaries.zip`
4. **VM** downloads and deploys the latest release (manually or automatically)

## Testing

After deployment, verify the application is working:

```powershell
# Test API endpoint
Invoke-RestMethod -Uri "http://localhost:8080/api/customers"

# Check application version
Get-Content C:\Apps\ModernizeInfraApp\version.txt
```

## Troubleshooting

### "Cannot download from GitHub"
- Check internet connectivity
- Verify firewall allows HTTPS traffic
- Try running: `Test-NetConnection raw.githubusercontent.com -Port 443`

### "Application won't start"
- Check if .NET runtime is installed: `dotnet --version`
- Verify SQL Server is running: `Get-Service MSSQLSERVER`
- Check connection strings in `appsettings.json`

### "No releases found"
- GitHub Actions workflow must complete successfully first
- Check GitHub Actions tab in repository for build status
- Manually trigger workflow if needed

## Need More Details?

See [DEPLOYMENT.md](./DEPLOYMENT.md) for complete documentation including:
- Detailed workflow explanations
- Advanced configuration options
- CI/CD with Azure integration
- Security considerations
- Full troubleshooting guide
