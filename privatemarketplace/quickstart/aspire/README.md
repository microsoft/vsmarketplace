# VS Code Private Marketplace - Quickstart Tutorial

This quickstart helps you set up and test a local VS Code Private Marketplace using .NET Aspire.

## Prerequisites

Before you begin, ensure you have:
- **Docker Desktop** installed and running
- **PowerShell** (pwsh) for running the setup script

## Getting Started

### Step 1: Run the Setup Script

Open PowerShell and run the quickstart script. This will automatically download and install all required components:

```powershell
irm https://raw.githubusercontent.com/mcumming/vsmarketplace/main/privatemarketplace/quickstart/aspire/Run-PrivateMarketplace.ps1 | iex
```

The script will:
- Download the quickstart files to a temporary folder
- Install a portable version of VS Code
- Install .NET SDK 10 locally
- Install Aspire CLI locally
- Prompt you to install VS Code Group Policy templates (requires admin privileges)
- Start the Private Marketplace container via Aspire

### Step 2: Access the Aspire Dashboard

Once Aspire starts, the dashboard will open automatically in your browser. If it doesn't open automatically, look for the dashboard URL in the terminal output (typically `https://localhost:15888`) and open it manually.

You'll see the `vscode-private-marketplace` resource with several available commands.

## Using the Private Marketplace

### Launch the Marketplace Home Page

1. In the Aspire dashboard, locate the `vscode-private-marketplace` resource
2. Click the **Home** link in the endpoints section to open the marketplace web interface
3. Browse available extensions in your private marketplace

### Configure Group Policy (Required for VS Code)

To connect VS Code to your private marketplace, you need to configure the Private Marketplace URL policy:

1. In the Aspire dashboard, find the `vscode-private-marketplace` resource
2. Click the **Open Group Policy Editor** command button
   - **Note**: This button only appears if you installed the administrative templates during setup
3. In the Group Policy Editor:
   - Navigate to: **User Configuration → Administrative Templates → Visual Studio Code → Extensions**
   - Double-click **Extension Gallery Service URL**
   - Select **Enabled**
   - Enter the marketplace URL (shown in the Aspire dashboard endpoints)
   - Click **OK**
4. Close the Group Policy Editor

### Launch VS Code Connected to Private Marketplace

1. In the Aspire dashboard, click the **Open VS Code** command button
   - This launches the portable VS Code instance with the private marketplace configured
2. Open the Extensions view (`Ctrl+Shift+X`)
3. Search for extensions - you'll see only those available in your private marketplace
4. Install extensions from your private marketplace as usual

## Adding Extensions to Your Private Marketplace

To add extensions to your private marketplace:

1. Download `.vsix` files for the extensions you want to include
2. Place them in the `data/extensions` folder in your temporary installation directory
3. Restart the Aspire application to refresh the marketplace

## Restoring Normal Marketplace Access

When you're done testing, restore normal VS Code Marketplace access:

1. Click **Open Group Policy Editor** in the Aspire dashboard
2. Navigate to: **User Configuration → Administrative Templates → Visual Studio Code → Extensions**
3. Set **Extension Gallery Service URL** to **Not Configured**
4. Click **OK** and close the Group Policy Editor

## Cleanup

After stopping Aspire (press `Ctrl+C` in the terminal), you'll be prompted to remove the temporary installation folder. Choose `y` to clean up all installed files, or `n` to keep them for future use.

### Manual Cleanup

If you need to manually clean up the installation:

1. **Remove the Group Policy setting:**
   - Open Group Policy Editor (`gpedit.msc`)
   - Navigate to: **User Configuration → Administrative Templates → Visual Studio Code → Extensions**
   - Set **Extension Gallery Service URL** to **Not Configured**
   - Click **OK**

2. **Delete the temporary installation folder:**
   ```powershell
   Remove-Item -Path "$env:TEMP\privatemarketplace-quickstart" -Recurse -Force
   ```

3. **Optional: Remove the administrative templates:**
   - Open PowerShell as Administrator
   - Run the following commands:
   ```powershell
   Remove-Item -Path "$env:WINDIR\PolicyDefinitions\VSCode.admx" -Force
   Get-ChildItem -Path "$env:WINDIR\PolicyDefinitions" -Directory | ForEach-Object {
       $admlFile = Join-Path $_.FullName "VSCode.adml"
       if (Test-Path $admlFile) {
           Remove-Item -Path $admlFile -Force
       }
   }
   ```

## Troubleshooting

**Group Policy Editor command not appearing?**

If you skipped the administrative templates installation during setup, you can install them manually:

1. Stop the Aspire application (press `Ctrl+C` in the terminal)
2. Open PowerShell as Administrator (right-click → Run as Administrator)
3. Navigate to the temporary installation folder:
   ```powershell
   cd $env:TEMP\privatemarketplace-quickstart
   ```
4. Run the script with the install templates parameter:
   ```powershell
   .\Run-PrivateMarketplace.ps1 -InstallAdminTemplates
   ```
5. Restart the Aspire application:
   ```powershell
   aspire run
   ```

The Group Policy Editor command should now appear in the Aspire dashboard.

**VS Code not connecting to private marketplace?**
- Verify the Group Policy setting is enabled and contains the correct URL
- Restart VS Code after changing the policy

**Extensions not appearing?**
- Check that `.vsix` files are in the `data/extensions` folder
- Verify the container is running (check Aspire dashboard)
- Look at the logs in the `data/logs` folder
