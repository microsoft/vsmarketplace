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
3. On the marketplace home page, you'll see:
   - The **Private Marketplace URL** displayed with a copy icon
   - The **Published Extensions** section showing sample extensions that are already available
4. Click the **copy icon** to copy the marketplace URL to your clipboard
   - Keep this page open or save the URL - you'll need it in the next step

### Configure Group Policy (Required for VS Code)

Now that you have the marketplace URL, configure VS Code to use your private marketplace:

1. Return to the Aspire dashboard and find the `vscode-private-marketplace` resource
2. Click the **Actions** menu (three dots) to see available commands
3. Select **Open Group Policy Editor** from the menu
   - **Note**: This command only appears if you installed the administrative templates during setup

![Aspire Actions Menu](images/aspire-actions-menu.png)
3. In the Group Policy Editor:
   - Navigate to: **User Configuration → Administrative Templates → Visual Studio Code → Extensions**
   - Double-click **Extension Gallery Service URL**
   - Select **Enabled**
   - **Paste the marketplace URL** you copied from the home page into the URL field
   - Click **OK**
4. Close the Group Policy Editor

### Launch VS Code Connected to Private Marketplace

1. In the Aspire dashboard, open the **Actions** menu for the `vscode-private-marketplace` resource
2. Select **Open VS Code** from the menu
   - This launches the portable VS Code instance with the private marketplace configured
2. Open the Extensions view (`Ctrl+Shift+X`)
3. Search for extensions - you'll see only those available in your private marketplace
4. Install extensions from your private marketplace as usual

## Adding Extensions to Your Private Marketplace

To add extensions to your private marketplace:

The quickstart includes sample extensions that you can see on the marketplace home page in the **Published Extensions** section. To add more extensions:

### Step 1: Download VSIX Files

Choose one of these methods to get `.vsix` extension files:

**Option A: Download from VS Code Marketplace Website**
1. Visit [marketplace.visualstudio.com](https://marketplace.visualstudio.com/)
2. Search for the extension you want
3. On the extension's page, click the **Download Extension** link on the right side
4. Save the `.vsix` file to your computer

**Option B: Download from VS Code**
1. Open VS Code
2. Go to Extensions view (`Ctrl+Shift+X`)
3. Find the extension you want
4. Right-click on the extension and select **Copy Download Link**
5. Open the link in your browser to download the `.vsix` file

**Option C: Package Your Own Extension**
```powershell
cd your-extension-directory
vsce package
```

### Step 2: Add Extensions to the Marketplace

1. Locate the temporary installation folder: `$env:TEMP\privatemarketplace-quickstart`
2. Navigate to the `data\extensions` folder
3. Copy your `.vsix` files into this folder
4. Stop the Aspire application (press `Ctrl+C` in the terminal)
5. Restart Aspire:
   ```powershell
   cd $env:TEMP\privatemarketplace-quickstart
   aspire run
   ```

Your extensions will now appear in the private marketplace!

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
