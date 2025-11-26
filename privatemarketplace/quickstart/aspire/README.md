# VS Code Private Marketplace - Quickstart

This quickstart walks you through setting up and testing a local VS Code Private Marketplace using .NET Aspire. You'll learn how to install the marketplace, configure VS Code to use it, and explore different usage scenarios.

---

## Part 1: Installation

### Prerequisites

Before you begin, ensure you have:
- **Docker Desktop** installed and running
- **PowerShell** (pwsh) for running the setup script

### Run the Setup Script

Open PowerShell and run the quickstart script:

```powershell
irm https://raw.githubusercontent.com/mcumming/vsmarketplace/main/privatemarketplace/quickstart/aspire/Run-PrivateMarketplace.ps1 | iex
```

The script will automatically:
- Download the quickstart files to a temporary folder (`$env:TEMP\privatemarketplace-quickstart`)
- Install a portable version of VS Code
- Install .NET SDK 10 and Aspire CLI locally
- Prompt you to install VS Code Group Policy templates (requires admin privileges - **recommended**)
- Start the Private Marketplace container via Aspire

**Important**: When prompted to install administrative templates, choose **Yes (y)** to enable Group Policy configuration later.

### Access the Aspire Dashboard

Once installation completes, the Aspire dashboard will open automatically in your browser. If it doesn't open automatically, look for the dashboard URL in the terminal output and open it manually.

![Aspire Dashboard URL in Terminal](images/aspire-dashboard-url.png)

**What is the Aspire Dashboard?**
The Aspire dashboard is your control center for managing the private marketplace. It provides:
- Real-time status of your marketplace container
- Quick access to the marketplace web interface
- Commands to launch VS Code and configure settings
- Logs and monitoring information

In the dashboard, you'll see a resource named **`vscode-private-marketplace`** - this is your private marketplace container.

---

## Part 2: Configuring VS Code

Now let's configure VS Code to use your private marketplace instead of the public VS Code Marketplace.

### Step 1: Get Your Marketplace URL

1. In the Aspire dashboard, find the **`vscode-private-marketplace`** resource
2. In the **Endpoints** section, click the **Home** link
   - This opens your marketplace's web interface in a new browser tab
3. On the marketplace home page, you'll see:
   - **Private Marketplace URL** at the top with a copy icon (📋)
   - **Published Extensions** section showing sample extensions already available
4. Click the **copy icon** next to the marketplace URL to copy it to your clipboard
   - You'll need this URL in the next step

**Tip**: Keep the marketplace home page open in a browser tab - you'll refer to it throughout the quickstart.

### Step 2: Configure Group Policy

1. Return to the Aspire dashboard browser tab
2. Locate the **`vscode-private-marketplace`** resource
3. Click the **Actions** button (three vertical dots ⋮) on the right side of the resource row
   
   ![Aspire Actions Menu](images/aspire-actions-menu.png)

4. From the Actions menu, select **Open Group Policy Editor**
   - **Note**: If this option doesn't appear, see the [Troubleshooting](#troubleshooting) section below
5. In the Group Policy Editor window that opens:
   - Navigate to: **User Configuration → Administrative Templates → Visual Studio Code → Extensions**
   - Double-click **Extension Gallery Service URL**
   - Select **Enabled**
   - **Paste** the marketplace URL you copied earlier into the URL field
   - Click **OK**
6. Close the Group Policy Editor

**What just happened?**
You configured Windows Group Policy to redirect VS Code's extension marketplace to your private instance. VS Code will now only show extensions from your private marketplace.

### Step 3: Launch VS Code

1. Return to the Aspire dashboard
2. Click the **Actions** button (⋮) for the **`vscode-private-marketplace`** resource
3. Select **Open VS Code** from the menu
   - This launches the portable VS Code instance configured to use your private marketplace
4. Once VS Code opens, click the Extensions icon in the sidebar (or press `Ctrl+Shift+X`)
5. You'll see only the sample extensions from your private marketplace

**Congratulations!** VS Code is now connected to your private marketplace.

---

## Part 3: Usage Scenarios

Now that you have a working private marketplace, try these common scenarios:

### Scenario 1: Adding Extensions to Your Marketplace

The quickstart includes sample extensions, but you'll want to add your own.

**Download VSIX Files**

Choose one of these methods:

**Option A: From VS Code Marketplace Website**
1. Visit [marketplace.visualstudio.com](https://marketplace.visualstudio.com/)
2. Search for the extension you want
3. Click the **Download Extension** link on the right side of the extension page
4. Save the `.vsix` file to your computer

**Option B: From VS Code**
1. Open VS Code (any instance)
2. Press `Ctrl+Shift+X` to open Extensions
3. Find the extension you want
4. Right-click the extension → **Copy Download Link**
5. Paste the link in your browser to download the `.vsix` file

**Option C: Package Your Own Extension**
```powershell
cd your-extension-directory
vsce package
```

**Add Extensions to the Marketplace**

1. Open File Explorer and navigate to: `$env:TEMP\privatemarketplace-quickstart\data\extensions`
2. Copy your `.vsix` files into this folder
3. Return to your terminal running Aspire and press `Ctrl+C` to stop it
4. Restart Aspire:
   ```powershell
   cd $env:TEMP\privatemarketplace-quickstart
   aspire run
   ```
5. Refresh your marketplace home page in the browser - your new extensions will appear!
6. In VS Code, reload the Extensions view to see the new extensions

### Scenario 2: Viewing Marketplace Logs

Monitor what's happening in your marketplace:

1. In the Aspire dashboard, click the **Actions** button (⋮) for **`vscode-private-marketplace`**
2. Select **Console logs** to see real-time container output
3. Or select **Structured logs** for formatted, searchable logs
4. Use logs to troubleshoot issues or monitor extension requests

### Scenario 3: Managing the Marketplace Container

Control your marketplace lifecycle:

**Stop the Marketplace**
1. In the Aspire dashboard, click **Actions** (⋮)
2. Select **Stop**
3. The marketplace is now offline

**Restart the Marketplace**
1. Click **Actions** (⋮)
2. Select **Restart**
3. Wait for the status to show "Running"

**View Detailed Information**
1. Click **Actions** (⋮)
2. Select **View details**
3. See complete resource information, environment variables, and configuration

---

## Part 4: Cleanup

### Restoring Normal VS Code Access

When you're done testing, restore VS Code to use the public marketplace:

1. In the Aspire dashboard, click **Actions** (⋮) for **`vscode-private-marketplace`**
2. Select **Open Group Policy Editor**
3. Navigate to: **User Configuration → Administrative Templates → Visual Studio Code → Extensions**
4. Double-click **Extension Gallery Service URL**
5. Select **Not Configured**
6. Click **OK** and close the Group Policy Editor
7. Restart VS Code to reconnect to the public marketplace

### Remove Installation Files

1. In your terminal, press `Ctrl+C` to stop Aspire
2. When prompted, choose **Yes (y)** to remove the temporary folder
3. All quickstart files will be deleted from `$env:TEMP\privatemarketplace-quickstart`

**Optional: Remove Administrative Templates**

If you want to completely remove the Group Policy templates:

1. Open PowerShell as Administrator
2. Run:
   ```powershell
   Remove-Item -Path "$env:WINDIR\PolicyDefinitions\VSCode.admx" -Force
   Get-ChildItem -Path "$env:WINDIR\PolicyDefinitions" -Directory | ForEach-Object {
       $admlFile = Join-Path $_.FullName "VSCode.adml"
       if (Test-Path $admlFile) {
           Remove-Item -Path $admlFile -Force
       }
   }
   ```

### Manual Cleanup

If automatic cleanup fails:

```powershell
# Remove temporary folder
Remove-Item -Path "$env:TEMP\privatemarketplace-quickstart" -Recurse -Force

# Remove Group Policy setting
# Open Group Policy Editor (gpedit.msc) and set:
# User Configuration → Administrative Templates → Visual Studio Code → Extensions
# → Extension Gallery Service URL → Not Configured
```

---

## Part 5: Troubleshooting

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
