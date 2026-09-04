# Private Marketplace for Visual Studio - Quickstart

This quickstart walks you through setting up and testing a local Private Marketplace for the Visual Studio family of products using [Aspire](https://aspire.dev) on Windows. You'll learn how to install the marketplace, configure a client to use it, and explore different usage scenarios.

Installing and hosting the marketplace is the same regardless of which client you use. Connecting a client to it is client-specific:

- **Visual Studio Code** - connection instructions are available today.
- **Visual Studio** - connection guidance is coming soon.

---

## Part 1: Installation

### Prerequisites

Before you begin, ensure you have:
- **Docker Desktop** installed and running. If it's missing and `winget` is available, the setup script can install it for you after prompting for confirmation.
- **PowerShell 5.1 or later** for running the setup script (Windows PowerShell or PowerShell 7)
- **Internet access** to download the quickstart and its dependencies

By default the quickstart installs its own portable copies of VS Code, the .NET SDK, and the Aspire CLI, so nothing already on the machine is used or altered. The `-UseGlobalInstalls` option changes that - see [Reusing existing installations](#reusing-existing-installations).

> [!IMPORTANT]
  Using a machine-wide VS Code installation means the quickstart's configuration is applied to the VS Code you use every day. The Group Policy setting in [Step 2](#step-2-configure-group-policy) changes the extension gallery for every VS Code installation on the machine, so your normal editor will use the Private Marketplace instead of the public Marketplace until you set the policy back to **Not Configured**. See [Restoring Normal Client Access](#restoring-normal-client-access) to undo it.

### Run the Setup Script

> [!IMPORTANT]
  Never run scripts from untrusted sources, always review the script before running it.
  Always verify the script's hash before executing. The expected hash can be found in the repository or release notes.

The script will automatically:
- Check for and install missing prerequisites (after prompting for confirmation):
  - Docker Desktop (if not found)
  - Download quickstart files to `$env:TEMP\privatemarketplace-quickstart`
  - Portable VS Code
  - Portable .NET SDK 10.0+
  - Portable Aspire CLI version 13+
- Prompt you to install VS Code Group Policy templates (requires admin privileges - **optional**)
- Start Docker Desktop if not running
- Launch the Private Marketplace container via Aspire

Portable VS Code is installed even if you only plan to evaluate hosting. It's used by the VS Code walkthrough in Part 2 and isn't part of the marketplace host itself.

> [!NOTE]
  The VS Code Group Policy templates are optional. Answer `n` to skip them - the quickstart can still launch VS Code connected to your Private Marketplace. You can install them later with `.\Run-PrivateMarketplace.ps1 -InstallAdminTemplates` if you want to configure clients through Windows Group Policy.

The Quickstart is installed into a temporary folder ($TEMP\privatemarketplace-quickstart), along with all of the dependencies, except Docker. To remove the Quickstart and all the dependencies, just delete the temporary folder, and uninstall Docker, if desired. The script will attempt to uninstall Docker and remove the temporary folder after Quickstart exits.

The Private Marketplace Quickstart is installed using an installation script available for PowerShell on Windows.

#### Download and install

All commands in this quickstart run in a **PowerShell** terminal. Open one, then run:

```powershell
irm https://raw.githubusercontent.com/microsoft/vsmarketplace/main/privatemarketplace/quickstart/aspire/Run-PrivateMarketplace.ps1 | iex
```

Alternatively, you can download the script and run it as a two-step process:

1. Open a PowerShell terminal.

2. Download the script and save it as a file:

   ```powershell
   irm https://raw.githubusercontent.com/microsoft/vsmarketplace/main/privatemarketplace/quickstart/aspire/Run-PrivateMarketplace.ps1 -OutFile Run-PrivateMarketplace.ps1
   ```

3. Review the script, then run it to install the required components and the Private Marketplace container:

   ```powershell
   .\Run-PrivateMarketplace.ps1
   ```

> [!NOTE]
  If PowerShell blocks the downloaded script because of your execution policy, run `Unblock-File .\Run-PrivateMarketplace.ps1` and then run it again.

You should see output similar to the following snippet:
  ```text
  Private Marketplace for VS Code Quickstart
  
    Checking prerequisites...
    Checking for Docker...
    Docker detected: Docker version 29.0.1, build eedd969
    Checking for local VS Code...
    Local VS Code not found
    Checking for local Aspire CLI...
    Local Aspire CLI not found
    Checking for local .NET SDK...
    Local .NET SDK not found
    Checking for quickstart files...
    Folder exists but appears incomplete (apphost.cs not found)
   
    === Missing Prerequisites ===
    - VS Code (portable)
    - Aspire CLI (version 13+)
    - .NET SDK 10.0.100+ (local)
    - Quickstart Files
    - VS Code Administrative Templates (requires admin privileges)

    The following will be installed:
    - VS Code (portable): via local portable installation
       Target: C:\Users\mcumming\AppData\Local\Temp\privatemarketplace-quickstart\.vscode
       Source: https://code.visualstudio.com/
    - Aspire CLI (version 13+) (local): via local portable installation
       Target: C:\Users\mcumming\AppData\Local\Temp\privatemarketplace-quickstart\.aspire
       Source: https://learn.microsoft.com/dotnet/aspire
    - .NET SDK 10.0.100+ (local): via dotnet-install script
       Target: C:\Users\mcumming\AppData\Local\Temp\privatemarketplace-quickstart\.dotnet
       Source: https://dotnet.microsoft.com/download/dotnet/10.0
    - Quickstart Files: via ZIP download
       Source: https://github.com/mcumming/vsmarketplace
       Target: C:\Users\mcumming\AppData\Local\Temp\privatemarketplace-quickstart
    - VS Code Administrative Templates: via elevated script execution
       Note: Requires administrator privileges (UAC prompt)
   
    Do you want to proceed with installation? (y/n):
  ```

#### Reusing existing installations

By default the quickstart installs its own portable copies of VS Code, the .NET SDK, and the Aspire CLI into the temporary folder, so it never interferes with what you already have installed.

If you would rather reuse tools already on the machine, run the script with `-UseGlobalInstalls`:

```powershell
.\Run-PrivateMarketplace.ps1 -UseGlobalInstalls
```

Each tool is used only when it meets a minimum version:

| Tool | Minimum version |
| --- | --- |
| VS Code | 1.99 |
| .NET SDK | 10.0.100 |
| Aspire CLI | 13.0.0 |

Anything missing or too old is still installed locally, so you can mix the two. Docker Desktop is always used from the machine.

> [!NOTE]
  Machine-wide VS Code installations ship `VSCode.admx` without the `VSCode.adml` language files. If you plan to configure the marketplace through Group Policy, run the quickstart without `-UseGlobalInstalls` so the portable VS Code, which includes the language files, is used.

### Access the Aspire Dashboard

Once installation completes, the Aspire dashboard will open automatically in your browser. If it doesn't open automatically, look for the dashboard URL in the terminal output and open it manually.

![Aspire Dashboard URL in Terminal](images/aspire-dashboard-url.png)

**What is the Aspire Dashboard?**
The Aspire dashboard is your control center for managing the Private Marketplace. It provides:
- Real-time status of your marketplace container
- Quick access to the marketplace web interface
- Commands to launch VS Code and configure settings
- Logs and monitoring information

In the dashboard, you'll see a resource named **`vscode-private-marketplace`** - this is your Private Marketplace container.

![Aspire Dashboard Resource Table](images/aspire-resource-table.png)

---

## Part 2: Configuring Your Client

Installation is complete and the marketplace is running. The next step depends on which client you're configuring.

### Visual Studio Code

Now let's configure VS Code to use your Private Marketplace instead of the public VS Code Marketplace.

> [!NOTE]
  The quickstart's **Open VS Code** command launches a portable VS Code instance already connected to your Private Marketplace, without Group Policy. Step 2 below configures Windows Group Policy, which is what you'd use to point your own VS Code installation - or your organization's - at the marketplace.

#### Step 1: Get Your Marketplace URL

1. In the Aspire dashboard, find the **`vscode-private-marketplace`** resource

   ![Aspire Dashboard Resource Table](images/aspire-resource-table.png)

2. In the **URLs** column, click the **Home** link
   - This opens your marketplace's web interface in a new browser tab
3. On the marketplace home page, you'll see the Private Marketplace URL at the top with a copy icon, and the Published Extensions section below

   ![Marketplace Home Page](images/marketplace-home.png)

4. Click the **copy icon** (blue button on the right) next to the marketplace URL to copy it to your clipboard
   - You'll need this URL in the next step

The quickstart includes three sample extensions preloaded in the marketplace:

![Published Extensions](images/published-extensions.png)

**Tip**: Keep the marketplace home page open in a browser tab - you'll refer to it throughout the quickstart.

#### Step 2: Configure Group Policy

1. Return to the Aspire dashboard browser tab
2. Locate the **`vscode-private-marketplace`** resource
3. Click the **Actions** button (three vertical dots ⋮) on the right side of the resource row
   
   ![Aspire Actions Menu](images/aspire-actions-menu.png)

4. From the Actions menu, select **Open Group Policy Editor**

> [!NOTE]
  If this option doesn't appear, see the [Troubleshooting](#part-5-troubleshooting) section below

5. In the Group Policy Editor window that opens, navigate to the Extensions folder:   
 
> [!NOTE]
  The Group Policy Editor window might not open in the foreground, look in the taskbar for the application.

   ![Group Policy Editor](images/gpedit-extensions.png)

   - Navigate to: **User Configuration → Administrative Templates → Visual Studio Code → Extensions**
   - Double-click **Extension Gallery Service URL**
   - In the settings window, select **Enabled**
   - **Paste** the marketplace URL you copied earlier into the **ExtensionGalleryServiceUrl** field
   
   ![Extension Gallery Service URL Setting](images/gpedit-setting.png)

   - Click **OK**
6. Close the Group Policy Editor

**What just happened?**
You configured Windows Group Policy to redirect VS Code's extension marketplace to your private instance. VS Code will now only show extensions from your Private Marketplace.

#### Step 3: Launch VS Code

1. Return to the Aspire dashboard
2. Click the **Actions** button (⋮) for the **`vscode-private-marketplace`** resource

   ![Aspire Actions Menu](images/aspire-actions-menu.png)

3. Select **Open VS Code** from the menu
   - This launches the portable VS Code instance configured to use your Private Marketplace
4. Once VS Code opens, **sign in to GitHub**:
   - Click the **Accounts** icon in the lower-left corner (or the profile icon)
   - Select **Sign in to access Extensions Marketplace...**

   ![VS Code Account Menu](images/vscode-account-menu.png)

   - Complete the authentication process in your browser
   
> [!IMPORTANT]
  You must sign in to GitHub before extensions will be available

5. After signing in, click the Extensions icon in the sidebar (or press `Ctrl+Shift+X`)
6. You'll see the sample extensions from your Private Marketplace listed first, followed by public extensions.

**Congratulations!** VS Code is now connected to your Private Marketplace.

### Visual Studio

Connection guidance for Visual Studio is coming soon.

---

## Part 3: Usage Scenarios

Now that you have a working Private Marketplace, try these common scenarios:

### Scenario 1: Adding Extensions to Your Marketplace

The quickstart includes sample extensions, but you'll want to add your own, or rehost extensions from the public Marketplace

**Download VSIX Files**

*Visual Studio Code*

To download extension VSIX files from the public Marketplace for rehosting:

1. Open VS Code (any instance connected to the public marketplace)
2. Press `Ctrl+Shift+X` to open Extensions
3. Find the extension you want
4. Right-click the extension → **Download VSIX**
5. Select the location to save the downloaded `.vsix` file to

*Visual Studio*

Guidance for obtaining Visual Studio extension packages is coming soon.

**Add Extensions to the Marketplace**

1. Open File Explorer and navigate to: `$env:TEMP\privatemarketplace-quickstart\data\extensions`
2. Copy your `.vsix` files into this folder
3. Refresh your marketplace home page in the browser - your new extensions will appear. The marketplace processes extensions as it discovers them, so it may take a few refreshes before they're all listed.
4. In your client, reload the Extensions view to see the new extensions

### Scenario 2: Restricting Extensions to Specific Publishers

You can configure your client to only allow extensions from specific publishers, such as your organization's internal publisher.

#### Visual Studio Code

**Configure Allowed Extensions Policy**

1. In the Aspire dashboard, click **Actions** (⋮) for **`vscode-private-marketplace`**
2. Select **Open Group Policy Editor**
3. Navigate to: **User Configuration → Administrative Templates → Visual Studio Code → Extensions**
4. Double-click **Allowed Extensions**
5. Select **Enabled**
6. In the **AllowedExtensions** field, enter the following JSON to allow only Contoso extensions:
   ```json
   {"Contoso": true}
   ```
7. Click **OK** and close the Group Policy Editor
8. Restart VS Code (close and reopen using the **Open VS Code** command in the Aspire dashboard)
9. In the Extensions view, only extensions from the Contoso publisher can be installed.

**What just happened?**
The `AllowedExtensions` policy controls which extensions can be installed. By setting `"Contoso": true`, you've restricted VS Code to only allow installation of extensions published by Contoso. All other publishers are blocked. See the [VS Code Documentation](https://code.visualstudio.com/docs/setup/enterprise#_configure-allowed-extensions) for more ways to configure the Allowed Extensions setting.

**Other Allowed Extensions Examples:**

To allow multiple publishers:
```json
{"Contoso": true, "microsoft": true}
```

To allow specific extensions only:
```json
{"Contoso.contosocopilot": true, "Contoso.contosooss": true}
```

To block a specific extension from an allowed publisher:
```json
{"Contoso": true, "Contoso.contosopack": false}
```

**Restore Default (Allow All Extensions):**
1. Return to the **Allowed Extensions** policy in Group Policy Editor
2. Select **Not Configured**
3. Click **OK**
4. Restart VS Code

#### Visual Studio

Guidance for restricting extensions in Visual Studio is coming soon.

### Scenario 3: Configure Upstreaming to Public Marketplace

Upstreaming is a feature of the Private Marketplace that makes the extensions in the public Marketplace available to VS Code clients. Upstreaming has three modes of operation, "None", "Search" and "SearchAndAssets". 

By changing the mode the Private Marketplace can support different scenarios
- `None`: No upstreaming. Only private extensions are available.
- `Search`: Only search queries for public extensions are proxied. Asset downloads (VSIX, icons, etc.) are fetched directly from the Public Marketplace by VS Code.
- `SearchAndAssets`: Both search queries and asset downloads for public extensions are fetched through the Private Marketplace. This mode ensures all Public Visual Studio Marketplace requests go through your Private Marketplace instance, and clients do not contact the Public Visual Studio Marketplace directly.
 

To change the Upstreaming mode in the Quickstart:

> [!IMPORTANT]
  The upstreaming mode is compiled into the AppHost, so changing it requires restarting the **AppHost**. Stopping and starting the **`vscode-private-marketplace`** resource from the Aspire dashboard is not enough - the container's configuration is built when the AppHost starts.

1. Close VS Code if it is open
1. In the terminal running Aspire, press `Ctrl+C` to stop the AppHost
1. When prompted to remove the temporary folder, answer **`n`**. Answering `y` deletes the quickstart and all of its dependencies.
1. Open the `$env:TEMP\privatemarketplace-quickstart\apphost.cs` file in an editor such as VS Code.
1. Locate the following section:

   ```csharp
   14   builder
   15      .AddVSCodePrivateMarketplace("vscode-private-marketplace")
   16      .WithMarketplaceConfiguration(
   17         organizationName: "Contoso",
   18         contactSupportUri: "mailto:privatemktplace@microsoft.com",
   19         upstreamingMode: MarketplaceUpstreamingMode.SearchAndAssets)
   20      .WithOpenGroupPolicyEditorCommand()
   21      .WithOpenVSCodeCommand();
   ```
1. Change line 19 to:
   ```csharp
         upstreamingMode: MarketplaceUpstreamingMode.None
   ```
1. Save the file
1. Restart the quickstart from a PowerShell terminal:

   ```powershell
   cd $env:TEMP\privatemarketplace-quickstart
   .\Run-PrivateMarketplace.ps1
   ```

   The script detects the existing installation and relaunches Aspire with the rebuilt AppHost.
1. When the Aspire dashboard reopens, click the **Home** link

   You should see upstreaming to the public Marketplace is now disabled.

   ![Upstreaming is disabled](images/marketplace-upstreaming-disabled.png)

**Verify the change**

*Visual Studio Code*

1. Open VS Code from the Actions menu
2. In the Extensions view, only extensions published through the Private Marketplace are listed and installable.

*Visual Studio*

Verification steps for Visual Studio are coming soon.

### Scenario 4: Viewing Marketplace Logs

Monitor what's happening in your marketplace:

1. In the Aspire dashboard, click the **Actions** button (⋮) for **`vscode-private-marketplace`**
2. Select **Console logs** to see real-time container output
3. Or select **Structured logs** for formatted, searchable logs
4. Use logs to troubleshoot issues or monitor extension requests

### Aspire Tips: Managing the Marketplace Container

Control your marketplace lifecycle:

**Start the Marketplace**
1. Click **Actions** (⋮)
2. Select **Start**
3. Wait for the status to show "Running"

**Stop the Marketplace**
1. In the Aspire dashboard, click **Actions** (⋮)
2. Select **Stop**
3. The marketplace is now offline

**View Detailed Information**
1. Click **Actions** (⋮)
2. Select **View details**
3. See complete resource information, environment variables, and configuration

---

## Part 4: Cleanup

### Restoring Normal Client Access

When you're done testing, restore your client to use the public marketplace.

#### Visual Studio Code

If you configured Group Policy in Part 2, clear it:

1. In the Aspire dashboard, click **Actions** (⋮) for **`vscode-private-marketplace`**
2. Select **Open Group Policy Editor**
3. Navigate to: **User Configuration → Administrative Templates → Visual Studio Code → Extensions**
4. Double-click **Extension Gallery Service URL**
5. Select **Not Configured**
6. Click **OK** and close the Group Policy Editor
7. Restart VS Code to reconnect to the public marketplace

The portable VS Code instance launched by the quickstart is removed along with the temporary folder, so it needs no separate cleanup.

#### Visual Studio

Guidance for restoring Visual Studio is coming soon.

### Remove Installation Files

1. In the terminal running Aspire, press `Ctrl+C` to stop it
2. When prompted, choose **Yes (y)** to remove the temporary folder
3. All quickstart files will be deleted from `$env:TEMP\privatemarketplace-quickstart`

**Optional: Remove Administrative Templates**

If you installed the VS Code Group Policy templates and want to remove them:

1. Open PowerShell as Administrator
2. Navigate to the temporary installation folder:
   ```powershell
   cd $env:TEMP\privatemarketplace-quickstart
   ```
3. Run the script with the remove templates parameter:
   ```powershell
   .\Run-PrivateMarketplace.ps1 -RemoveAdminTemplates
   ```

### Manual Cleanup

If automatic cleanup fails, run the following in a PowerShell terminal:

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

### Visual Studio Code

**Group Policy Editor command not appearing?**

If you skipped the administrative templates installation during setup, or they failed to install, you can install them manually:

1. In the Aspire dashboard, click **Actions** (⋮) for **`vscode-private-marketplace`**
2. Select **Stop** to stop the marketplace container
3. Open PowerShell as Administrator (right-click → Run as Administrator)
4. Navigate to the temporary installation folder:
   ```powershell
   cd $env:TEMP\privatemarketplace-quickstart
   ```
5. Run the script with the install templates parameter:
   ```powershell
   .\Run-PrivateMarketplace.ps1 -InstallAdminTemplates
   ```
6. Return to the Aspire dashboard
7. Click **Actions** (⋮) for **`vscode-private-marketplace`**
8. Select **Start** to start the marketplace container

The Group Policy Editor command should now appear in the Aspire dashboard Actions menu.

**VS Code not connecting to Private Marketplace?**
- Verify the Group Policy setting is enabled and contains the correct URL
- Restart VS Code after changing the policy

### Marketplace Host

**Extensions not appearing?**
- Check that `.vsix` files are in the `data/extensions` folder
- Verify the container is running (check Aspire dashboard)
- Look at the logs in the `data/logs` folder
