<#
.SYNOPSIS
    Sets up and runs a private VS Code marketplace quickstart environment.

.DESCRIPTION
    This script automates the installation and configuration of all prerequisites
    needed to run a private VS Code marketplace, including Docker, VS Code portable,
    .NET SDK, and Aspire CLI. All tools are installed locally in a temporary folder
    to avoid interfering with system-wide installations.

.PARAMETER InstallAdminTemplates
    When specified, only installs VS Code administrative templates (Group Policy ADMX/ADML files)
    to the Windows PolicyDefinitions folder and exits. Requires administrator privileges.

.PARAMETER RemoveAdminTemplates
    When specified, only removes VS Code administrative templates (Group Policy ADMX/ADML files)
    from the Windows PolicyDefinitions folder and exits. Requires administrator privileges.

.EXAMPLE
    .\Run-PrivateMarketplace.ps1
    Runs the full quickstart setup, checking and installing prerequisites as needed.

.EXAMPLE
    .\Run-PrivateMarketplace.ps1 -InstallAdminTemplates
    Installs only the VS Code administrative templates (requires elevation via UAC).

.EXAMPLE
    .\Run-PrivateMarketplace.ps1 -RemoveAdminTemplates
    Removes only the VS Code administrative templates (requires elevation via UAC).

.NOTES
    Requires: PowerShell 5.1 or later, Internet connection for downloads
    Administrator privileges required to install VS Code Group Policy templates (recommended for marketplace configuration)
    Exit Codes:
        0 - Success
        1 - Error occurred (see error messages)
        64 - UAC prompt cancelled by user
#>
[CmdletBinding()]
param(
    [Parameter(HelpMessage="Install VS Code administrative templates only (requires admin rights)")]
    [switch]$InstallAdminTemplates,
    
    [Parameter(HelpMessage="Remove VS Code administrative templates only (requires admin rights)")]
    [switch]$RemoveAdminTemplates
)

$ErrorActionPreference = "Stop"

#region Configuration
# Script configuration - modify these values to customize the behavior
$Config = @{
    # Repository settings
    RepoUrl = "https://github.com/mcumming/vsmarketplace"
    RepoBranch = "main"  # Change this to test different branches
    
    # Version requirements
    DotNetVersion = "10.0.100"  # Version of .NET SDK to install locally
    
    # Installation paths
    RootPath = Join-Path $env:TEMP "privatemarketplace-quickstart"
    
    # Timeout settings
    MaxDockerWaitTime = 120  # Maximum seconds to wait for Docker to start (first-time can take 90+ seconds)
    DockerCheckInterval = 2   # Seconds between Docker readiness checks
}

# Derived paths (calculated from configuration)
$Paths = @{
    Root = $Config.RootPath
    LocalVSCode = Join-Path $Config.RootPath ".vscode"
    LocalAspire = Join-Path $Config.RootPath ".aspire"
    LocalDotnet = Join-Path $Config.RootPath ".dotnet"
    Policies = Join-Path $Config.RootPath ".vscode\policies"
}
#endregion Configuration

#region Helper Functions
<#
.SYNOPSIS
    Tests if a command exists in the current environment.
#>
function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

<#
.SYNOPSIS
    Writes a status message with consistent formatting.
#>
function Write-StatusMessage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Gray')]
        [string]$Level = 'Info'
    )
    
    $colors = @{
        Info = 'Cyan'
        Success = 'Green'
        Warning = 'Yellow'
        Error = 'Red'
        Gray = 'Gray'
    }
    
    Write-Host $Message -ForegroundColor $colors[$Level]
}

<#
.SYNOPSIS
    Waits for a condition to become true within a timeout period.
#>
function Wait-ForCondition {
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$Condition,
        
        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 60,
        
        [Parameter(Mandatory=$false)]
        [int]$IntervalSeconds = 2,
        
        [Parameter(Mandatory=$false)]
        [string]$StatusMessage = "Waiting for condition"
    )
    
    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        # Show progress bar before checking condition
        $percentComplete = [Math]::Min(100, ($elapsed / $TimeoutSeconds) * 100)
        Write-Progress -Activity $StatusMessage -Status "$elapsed of $TimeoutSeconds seconds" -PercentComplete $percentComplete
        
        if (& $Condition) {
            Write-Progress -Activity $StatusMessage -Completed
            return $true
        }
        
        Start-Sleep -Seconds $IntervalSeconds
        $elapsed += $IntervalSeconds
    }
    
    Write-Progress -Activity $StatusMessage -Completed
    return $false
}

<#
.SYNOPSIS
    Removes specified paths from the user PATH environment variable.
#>
function Remove-PathFromEnvironment {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$PathPatterns
    )
    
    try {
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if (-not $userPath) {
            return
        }
        
        # Split path into components and filter out matching patterns
        $pathComponents = $userPath -split ';' | Where-Object { $_ }
        $filteredComponents = $pathComponents | Where-Object { 
            $path = $_
            $shouldKeep = $true
            foreach ($pattern in $PathPatterns) {
                if ($path -like $pattern) {
                    $shouldKeep = $false
                    break
                }
            }
            $shouldKeep
        }
        
        # Only update if there were changes
        if ($filteredComponents.Count -lt $pathComponents.Count) {
            $newPath = $filteredComponents -join ';'
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
            Write-StatusMessage "  Removed matching paths from user PATH." -Level Success
        } else {
            Write-StatusMessage "  No matching paths found in user PATH." -Level Gray
        }
    } catch {
        Write-StatusMessage "  Warning: Could not clean PATH environment variable: $_" -Level Warning
    }
}

<#
.SYNOPSIS
    Downloads a file and optionally verifies its hash.
#>
function Get-FileWithVerification {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        
        [Parameter(Mandatory=$true)]
        [string]$OutFile,
        
        [Parameter(Mandatory=$false)]
        [string]$ExpectedHash,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('SHA256', 'SHA1', 'MD5')]
        [string]$HashAlgorithm = 'SHA256'
    )
    
    try {
        Write-Verbose "Downloading from: $Url"
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
        
        if ($ExpectedHash) {
            Write-Verbose "Verifying hash..."
            $actualHash = (Get-FileHash -Path $OutFile -Algorithm $HashAlgorithm).Hash
            
            if ($actualHash -ne $ExpectedHash) {
                Remove-Item -Path $OutFile -Force -ErrorAction SilentlyContinue
                throw "Hash verification failed!`nExpected: $ExpectedHash`nActual: $actualHash"
            }
            
            Write-Verbose "Hash verification passed."
        }
        
        return $true
    } catch {
        Write-StatusMessage "  Download failed: $_" -Level Error
        return $false
    }
}

<#
.SYNOPSIS
    Executes a script block with progress indication.
#>
function Invoke-WithProgress {
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory=$true)]
        [string]$Activity,
        
        [Parameter(Mandatory=$false)]
        [string]$Status = "Processing..."
    )
    
    Write-Progress -Activity $Activity -Status $Status
    try {
        $result = & $ScriptBlock
        return $result
    }
    finally {
        Write-Progress -Activity $Activity -Completed
    }
}

<#
.SYNOPSIS
    Creates a prerequisite definition hashtable.
#>
function New-PrerequisiteInfo {
    param(
        [string]$Name,
        [string]$InstallMethod,
        [string]$ManualUrl,
        [string]$InstallPath,
        [string]$Version,
        [string]$DownloadMethod,
        [string]$TargetFolder
    )
    
    $info = @{ Name = $Name; InstallMethod = $InstallMethod }
    if ($ManualUrl) { $info.ManualUrl = $ManualUrl }
    if ($InstallPath) { $info.InstallPath = $InstallPath }
    if ($Version) { $info.Version = $Version }
    if ($DownloadMethod) { $info.DownloadMethod = $DownloadMethod }
    if ($TargetFolder) { $info.TargetFolder = $TargetFolder }
    return $info
}

<#
.SYNOPSIS
    Creates a directory if it doesn't exist.
#>
function New-DirectoryIfNeeded {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

<#
.SYNOPSIS
    Checks if VS Code administrative templates are installed.
#>
function Test-AdminTemplatesInstalled {
    $policyDefinitionsPath = Join-Path $env:WINDIR "PolicyDefinitions"
    $admxPath = Join-Path $policyDefinitionsPath "VSCode.admx"
    return (Test-Path $admxPath)
}
#endregion Helper Functions

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# If -InstallAdminTemplates parameter is passed, only install templates and exit
if ($InstallAdminTemplates) {
    if (-not $isAdmin) {
        Write-Host "Error: Must run as administrator to install administrative templates." -ForegroundColor Red
        Read-Host "Press Enter to continue..."
        exit 1
    }

    # Use configured paths
    $rootPath = $Paths.Root
    $localVSCodePath = $Paths.LocalVSCode
    
    # Set up logging in root folder (must be done before Start-Transcript)
    $logFile = Join-Path $rootPath "vscode-admin-template-install.log"
    $errorLogFile = "$logFile.err"
    
    # Create root path if it doesn't exist
    if (-not (Test-Path $rootPath)) {
        New-Item -ItemType Directory -Path $rootPath -Force | Out-Null
    }
    
    # Start transcript to capture all output
    Start-Transcript -Path $logFile -Force
    
    # Policies are inside the VS Code installation, check multiple possible locations
    $vscodePolicyPath = $null
    $possiblePolicyPaths = @(
        (Join-Path $localVSCodePath "resources\app\product.json"),
        (Join-Path $localVSCodePath "Code.exe")
    )
    
    # Find VS Code installation by looking for key files
    $vscodeFound = $false
    foreach ($testPath in $possiblePolicyPaths) {
        if (Test-Path $testPath) {
            $vscodeFound = $true
            break
        }
    }
    
    if (-not $vscodeFound) {
        Write-Host "Error: VS Code installation not found at: $localVSCodePath" -ForegroundColor Red
        Write-Host "Please ensure VS Code is installed before installing administrative templates." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    # Try to find policies folder in common locations
    $policySearchPaths = @(
        (Join-Path $localVSCodePath "resources\app\policies"),
        (Join-Path $localVSCodePath "policies")
    )
    
    foreach ($searchPath in $policySearchPaths) {
        if (Test-Path $searchPath) {
            $vscodePolicyPath = $searchPath
            break
        }
    }
    
    if (-not $vscodePolicyPath) {
        Write-Host "Error: Policies folder not found in VS Code installation." -ForegroundColor Red
        Write-Host "Searched locations:" -ForegroundColor Gray
        foreach ($searchPath in $policySearchPaths) {
            Write-Host "  - $searchPath" -ForegroundColor Gray
        }
        Read-Host "Press Enter to exit"
        exit 1
    }
        
    Write-Host "Installing VS Code administrative templates..." -ForegroundColor Cyan
    Write-Host "Root path: $rootPath" -ForegroundColor Gray
    Write-Host "VS Code path: $localVSCodePath" -ForegroundColor Gray
    Write-Host "Policy source path: $vscodePolicyPath" -ForegroundColor Gray
    
    try {
        $policyDefinitionsPath = Join-Path $env:WINDIR "PolicyDefinitions"
        Write-Host "Policy destination path: $policyDefinitionsPath" -ForegroundColor Gray
        
        # Copy main ADMX file
        $admxSource = Join-Path $vscodePolicyPath "VSCode.admx"
        $admxDest = Join-Path $policyDefinitionsPath "VSCode.admx"
        
        Write-Host "Looking for ADMX file at: $admxSource" -ForegroundColor Gray
        
        if (-not (Test-Path $admxSource)) {
            Write-Host "Error: VSCode.admx not found at: $admxSource" -ForegroundColor Red
            if (Test-Path $vscodePolicyPath) {
                Write-Host "Policies folder contents: $(( Get-ChildItem -Path $vscodePolicyPath).Name -join ', ')" -ForegroundColor Gray
            }
            Stop-Transcript
            exit 1
        }
        
        Copy-Item -Path $admxSource -Destination $admxDest -Force
        Write-Host "  Copied VSCode.admx to PolicyDefinitions" -ForegroundColor Green
        
        # Get all language folders in Windows PolicyDefinitions
        $windowsLangFolders = Get-ChildItem -Path $policyDefinitionsPath -Directory | Where-Object { $_.Name -match '^[a-z]{2}-[a-z]{2}$' }
        Write-Host "Found $($windowsLangFolders.Count) language folders in Windows PolicyDefinitions" -ForegroundColor Gray
        
        # Copy matching language ADML files
        $copiedCount = 0
        foreach ($langFolder in $windowsLangFolders) {
            $vscodeLangPath = Join-Path $vscodePolicyPath $langFolder.Name
            $admlSource = Join-Path $vscodeLangPath "VSCode.adml"
            
            if (Test-Path $admlSource) {
                $admlDest = Join-Path (Join-Path $policyDefinitionsPath $langFolder.Name) "VSCode.adml"
                Copy-Item -Path $admlSource -Destination $admlDest -Force
                Write-Host "  Copied VSCode.adml for language: $($langFolder.Name)" -ForegroundColor Green
                $copiedCount++
            }
        }
        
        Write-Host "Administrative templates installed successfully ($copiedCount language files)." -ForegroundColor Green
        
        # Verify installation
        Write-Host "`nVerifying installation..." -ForegroundColor Cyan
        $verificationFailed = $false
        
        # Check ADMX file
        if (-not (Test-Path $admxDest)) {
            Write-Host "  ERROR: VSCode.admx not found at destination: $admxDest" -ForegroundColor Red
            $verificationFailed = $true
        } else {
            Write-Host "  ✓ VSCode.admx verified" -ForegroundColor Green
        }
        
        # Check at least one ADML file
        if ($copiedCount -eq 0) {
            Write-Host "  WARNING: No language files were copied" -ForegroundColor Yellow
            $verificationFailed = $true
        } else {
            Write-Host "  ✓ $copiedCount language file(s) verified" -ForegroundColor Green
        }
        
        if ($verificationFailed) {
            Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Red
            Write-Host "Installation Verification FAILED" -ForegroundColor Red
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
            Write-Host "The administrative templates were not installed correctly." -ForegroundColor Yellow
            Write-Host "`nSource location: $vscodePolicyPath" -ForegroundColor Gray
            Write-Host "Destination: $policyDefinitionsPath" -ForegroundColor Gray
            Write-Host "Log file: $logFile" -ForegroundColor Gray
            Write-Host "`nPlease review the log and try again." -ForegroundColor Yellow
            Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Red
            Stop-Transcript
            Read-Host "Press Enter to exit"
            exit 1
        }
        
        Write-Host "`nInstallation verification passed!" -ForegroundColor Green
        Stop-Transcript
        exit 0
    } catch {
        Write-Host "Error installing administrative templates: $_" -ForegroundColor Red
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
        Stop-Transcript
        
        # Copy transcript to error log as well
        if (Test-Path $logFile) {
            Copy-Item -Path $logFile -Destination $errorLogFile -Force
        }
        
        Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host "Installation FAILED" -ForegroundColor Red
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host "Log file: $logFile" -ForegroundColor Gray
        Write-Host "Error log: $errorLogFile" -ForegroundColor Gray
        Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# If -RemoveAdminTemplates parameter is passed, only remove templates and exit
if ($RemoveAdminTemplates) {
    if (-not $isAdmin) {
        Write-Host "Error: Must run as administrator to remove administrative templates." -ForegroundColor Red
        Read-Host "Press Enter to continue..."
        exit 1
    }
    
    Write-Host "Removing VS Code administrative templates..." -ForegroundColor Cyan
    
    try {
        $policyDefinitionsPath = Join-Path $env:WINDIR "PolicyDefinitions"
        $admxPath = Join-Path $policyDefinitionsPath "VSCode.admx"
        
        Write-Host "Policy destination path: $policyDefinitionsPath" -ForegroundColor Gray
        
        # Remove main ADMX file
        if (Test-Path $admxPath) {
            Remove-Item -Path $admxPath -Force -ErrorAction Stop
            Write-Host "  Removed VSCode.admx" -ForegroundColor Green
        } else {
            Write-Host "  VSCode.admx not found (already removed)" -ForegroundColor Gray
        }
        
        # Remove ADML files from language folders
        $langFolders = Get-ChildItem -Path $policyDefinitionsPath -Directory | Where-Object { $_.Name -match '^[a-z]{2}-[a-z]{2}$' }
        $removedAdmlCount = 0
        
        foreach ($langFolder in $langFolders) {
            $admlPath = Join-Path $langFolder.FullName "VSCode.adml"
            if (Test-Path $admlPath) {
                Remove-Item -Path $admlPath -Force -ErrorAction SilentlyContinue
                Write-Host "  Removed VSCode.adml for language: $($langFolder.Name)" -ForegroundColor Green
                $removedAdmlCount++
            }
        }
        
        Write-Host "Administrative templates removed successfully ($removedAdmlCount language files)." -ForegroundColor Green
        Read-Host "Press Enter to exit"
        exit 0
    } catch {
        Write-Host "Error removing administrative templates: $_" -ForegroundColor Red
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

Write-StatusMessage "Private Marketplace for VS Code Quickstart" -Level Info

# Check and install prerequisites
Write-StatusMessage "`nChecking prerequisites..." -Level Info

# Initialize tracking variables
$missingPrereqs = @()
$dockerInstalled = $false
$vscodeInstalled = $false
$aspireInstalled = $false
$dotnetInstalled = $false
$repoExists = $false
$wingetAvailable = $false
$adminTemplatesHandled = $false  # Track if we've already prompted for admin templates

# Use configured values and paths
$repoUrl = $Config.RepoUrl
$repoBranch = $Config.RepoBranch
$rootPath = $Paths.Root
$dotnetVersion = $Config.DotNetVersion
$localVSCodePath = $Paths.LocalVSCode
$localAspirePath = $Paths.LocalAspire
$localDotnetPath = $Paths.LocalDotnet
$policiesPath = $Paths.Policies

# Check Docker
Write-Host "Checking for Docker..." -ForegroundColor Gray
try {
    $dockerVersion = docker --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Docker detected: $dockerVersion" -ForegroundColor Green
        $dockerInstalled = $true
    } else {
        throw "Docker not found"
    }
} catch {
    Write-Verbose "Docker check failed: $_"
    
    # Check if Docker Desktop is installed but just not in PATH or not running
    $dockerDesktopPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerDesktopPath) {
        Write-Host "  Docker Desktop installed but not accessible" -ForegroundColor Yellow
        $dockerInstalled = $true  # Mark as installed, will handle startup later
    } else {
        Write-Host "  Docker not found" -ForegroundColor Yellow
        $missingPrereqs += New-PrerequisiteInfo -Name "Docker Desktop" -InstallMethod "winget" `
            -ManualUrl "https://www.docker.com/products/docker-desktop"
    }
}# Check VS Code
Write-Host "Checking for VS Code..." -ForegroundColor Gray

# Check if root doesn't exist, VS Code can't exist either
if (-not (Test-Path $rootPath)) {
    Write-Host "  VS Code not found (quickstart folder not present)" -ForegroundColor Yellow
    $missingPrereqs += New-PrerequisiteInfo -Name "VS Code (portable)" -InstallMethod "vscode-local" `
        -InstallPath $localVSCodePath -ManualUrl "https://code.visualstudio.com/"
} else {
    $vscodeExePath = Join-Path $localVSCodePath "Code.exe"
    
    if (Test-Path $vscodeExePath) {
        Write-Host "  VS Code found at: $localVSCodePath" -ForegroundColor Green
        $vscodeInstalled = $true
    } else {
        Write-Host "  VS Code not found" -ForegroundColor Yellow
        $missingPrereqs += New-PrerequisiteInfo -Name "VS Code (portable)" -InstallMethod "vscode-local" `
            -InstallPath $localVSCodePath -ManualUrl "https://code.visualstudio.com/"
    }
}

# Check Aspire CLI (local installation)
Write-Host "Checking for Aspire CLI..." -ForegroundColor Gray

# If root doesn't exist, Aspire can't exist either
$aspirePrereq = New-PrerequisiteInfo -Name "Aspire CLI (version 13+)" -InstallMethod "aspire-local" `
    -InstallPath $localAspirePath -ManualUrl "https://learn.microsoft.com/dotnet/aspire"

if (-not (Test-Path $rootPath)) {
    Write-Host "  Aspire CLI not found (quickstart folder not present)" -ForegroundColor Yellow
    $missingPrereqs += $aspirePrereq
} else {
    $aspireExePath = Join-Path $localAspirePath "aspire.exe"
    if (Test-Path $aspireExePath) {
        Write-Host "  Aspire CLI found at: $localAspirePath" -ForegroundColor Green
        $aspireInstalled = $true
    } else {
        Write-Host "  Aspire CLI not found" -ForegroundColor Yellow
        $missingPrereqs += $aspirePrereq
    }
}

# Check for local .NET SDK installation
Write-Host "Checking for local .NET SDK..." -ForegroundColor Gray

# If root doesn't exist, .NET SDK can't exist either
$dotnetPrereq = New-PrerequisiteInfo -Name ".NET SDK $dotnetVersion (local)" -InstallMethod "dotnet-install" `
    -Version $dotnetVersion -InstallPath $localDotnetPath -ManualUrl "https://dotnet.microsoft.com/download/dotnet/10.0"

if (-not (Test-Path $rootPath)) {
    Write-Host "  Local .NET SDK not found (quickstart folder not present)" -ForegroundColor Yellow
    $missingPrereqs += $dotnetPrereq
} else {
    $localDotnetExePath = Join-Path $localDotnetPath "dotnet.exe"

    if (Test-Path $localDotnetExePath) {
        # Check the actual installed SDK versions
        try {
            $installedSdks = & $localDotnetExePath --list-sdks 2>$null
            $matchingSdk = $installedSdks | Where-Object { $_ -match "^$([regex]::Escape($dotnetVersion))\s" }
            
            if ($matchingSdk) {
                Write-Host "  Local .NET SDK $dotnetVersion found at: $localDotnetPath" -ForegroundColor Green
                $dotnetInstalled = $true
            } else {
                Write-Host "  Version $dotnetVersion missing. Installed: $($installedSdks -join ', ')" -ForegroundColor Yellow
                $missingPrereqs += $dotnetPrereq
            }
        } catch {
            Write-Host "  Error checking local .NET SDK: $_" -ForegroundColor Yellow
            $missingPrereqs += $dotnetPrereq
        }
    } else {
        Write-Host "  Local .NET SDK not found" -ForegroundColor Yellow
        $missingPrereqs += $dotnetPrereq
    }
}

# Check for quickstart files
Write-Host "Checking for quickstart files..." -ForegroundColor Gray
if (Test-Path $rootPath) {
    # Verify key files exist
    $apphostPath = Join-Path $rootPath "apphost.cs"
    if (Test-Path $apphostPath) {
        Write-Host "  Quickstart files found at: $rootPath" -ForegroundColor Green
        $repoExists = $true
    } else {
        Write-Host "  Folder exists but appears incomplete (apphost.cs not found)" -ForegroundColor Yellow
        $missingPrereqs += New-PrerequisiteInfo -Name "Quickstart Files" -InstallMethod "download" `
            -DownloadMethod "ZIP download" -TargetFolder $rootPath -ManualUrl $repoUrl
    }
} else {
    Write-Host "  Quickstart files not found" -ForegroundColor Yellow
    $missingPrereqs += New-PrerequisiteInfo -Name "Quickstart Files" -InstallMethod "download" `
        -DownloadMethod "ZIP download" -TargetFolder $rootPath -ManualUrl $repoUrl
}

# Check winget availability
$wingetAvailable = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)

# Check if admin templates are needed
$adminTemplatesNeeded = -not (Test-AdminTemplatesInstalled)

# Display summary if prerequisites are missing
if ($missingPrereqs.Count -gt 0 -or $adminTemplatesNeeded) {
    Write-Host "`n=== Missing Prerequisites ===" -ForegroundColor Yellow
    foreach ($prereq in $missingPrereqs) {
        Write-Host "  - $($prereq.Name)" -ForegroundColor Yellow
    }
    if ($adminTemplatesNeeded) {
        Write-Host "  - VS Code Administrative Templates (requires admin privileges)" -ForegroundColor Yellow
    }
    
    Write-Host "`nThe following will be installed:" -ForegroundColor Cyan
    foreach ($prereq in $missingPrereqs) {
        if ($prereq.InstallMethod -eq "winget" -and -not $wingetAvailable) {
            Write-Host "  - $($prereq.Name): Manual installation required" -ForegroundColor Yellow
            Write-Host "    Source: $($prereq.ManualUrl)" -ForegroundColor Gray
        } elseif ($prereq.InstallMethod -eq "winget") {
            Write-Host "  - $($prereq.Name): via winget" -ForegroundColor Green
            if ($prereq.ManualUrl) {
                Write-Host "    Source: $($prereq.ManualUrl)" -ForegroundColor Gray
            }
        } elseif ($prereq.InstallMethod -eq "vscode-local") {
            Write-Host "  - $($prereq.Name): via local portable installation" -ForegroundColor Green
            if ($prereq.InstallPath) {
                Write-Host "    Target: $($prereq.InstallPath)" -ForegroundColor Gray
            }
            if ($prereq.ManualUrl) {
                Write-Host "    Source: $($prereq.ManualUrl)" -ForegroundColor Gray
            }
        } elseif ($prereq.InstallMethod -eq "aspire-local") {
            Write-Host "  - $($prereq.Name): via local installation" -ForegroundColor Green
            if ($prereq.InstallPath) {
                Write-Host "    Target: $($prereq.InstallPath)" -ForegroundColor Gray
            }
            if ($prereq.ManualUrl) {
                Write-Host "    Source: $($prereq.ManualUrl)" -ForegroundColor Gray
            }
        } elseif ($prereq.InstallMethod -eq "download") {
            Write-Host "  - $($prereq.Name): via $($prereq.DownloadMethod)" -ForegroundColor Green
            if ($prereq.ManualUrl) {
                Write-Host "    Source: $($prereq.ManualUrl)" -ForegroundColor Gray
            }
            if ($prereq.TargetFolder) {
                Write-Host "    Target: $($prereq.TargetFolder)" -ForegroundColor Gray
            }
        } elseif ($prereq.InstallMethod -eq "dotnet-install") {
            Write-Host "  - $($prereq.Name): via dotnet-install script" -ForegroundColor Green
            if ($prereq.InstallPath) {
                Write-Host "    Target: $($prereq.InstallPath)" -ForegroundColor Gray
            }
            if ($prereq.ManualUrl) {
                Write-Host "    Source: $($prereq.ManualUrl)" -ForegroundColor Gray
            }
        }
    }
    if ($adminTemplatesNeeded) {
        Write-Host "  - VS Code Administrative Templates: via elevated script execution" -ForegroundColor Green
        Write-Host "    Note: Requires administrator privileges (UAC prompt)" -ForegroundColor Gray
    }
    
    # Prompt for confirmation
    Write-Host ""
    $response = Read-Host "Do you want to proceed with installation? (y/n)"
    if ($response -ne 'y') {
        Write-Host "Installation cancelled by user. Please install the missing prerequisites and run this script again." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n=== Installing Prerequisites ===" -ForegroundColor Cyan
    
    # Download quicklaunch files if missing
    if (-not $repoExists) {
        Write-Host "`nDownloading quicklaunch files..." -ForegroundColor Cyan
        
        New-DirectoryIfNeeded -Path $rootPath
        
        # Download only the privatemarketplace/quickstart folder
        Write-Host "  Downloading from repository (branch: $repoBranch)..." -ForegroundColor Gray
        $zipUrl = "$repoUrl/archive/refs/heads/$repoBranch.zip"
        $tempZipPath = Join-Path $env:TEMP "vsmarketplace-$repoBranch.zip"
        
        try {
            $downloadSuccess = Invoke-WithProgress -Activity "Downloading Quickstart Files" -Status "Downloading from repository..." -ScriptBlock {
                Get-FileWithVerification -Url $zipUrl -OutFile $tempZipPath
            }
            if (-not $downloadSuccess) {
                throw "Failed to download repository archive"
            }
            Write-Host "  ZIP downloaded successfully." -ForegroundColor Green
            
            # Extract files
            $tempExtractPath = Join-Path $env:TEMP "vsmarketplace-extract"
            if (Test-Path $tempExtractPath) {
                Remove-Item -Path $tempExtractPath -Recurse -Force
            }
            Write-Progress -Activity "Extracting Quickstart Files" -Status "Extracting files..."
            Expand-Archive -Path $tempZipPath -DestinationPath $tempExtractPath -Force
            Write-Progress -Activity "Extracting Quickstart Files" -Completed
            
            # Copy quicklaunch folder contents directly to root (excluding .dotnet, .aspire, .vscode)
            $extractedquicklaunchFolder = Join-Path $tempExtractPath "vsmarketplace-$repoBranch\privatemarketplace\quickstart\aspire"
            if (Test-Path $extractedquicklaunchFolder) {
                # Get all items in quicklaunch folder except hidden tool folders
                Get-ChildItem -Path $extractedquicklaunchFolder | Where-Object { 
                    $_.Name -notin @('.dotnet', '.aspire', '.vscode')
                } | ForEach-Object {
                    Copy-Item -Path $_.FullName -Destination $rootPath -Recurse -Force
                }
                Write-Host "  quicklaunch files copied successfully." -ForegroundColor Green
            } else {
                throw "aspire folder not found in downloaded archive"
            }
            
            # Clean up temporary files
            Remove-Item -Path $tempZipPath -Force
            Remove-Item -Path $tempExtractPath -Recurse -Force
            Write-Host "  Download complete." -ForegroundColor Green
            $repoExists = $true

            $appHostPath = Join-Path $rootPath "AppHost.cs"
            if (Test-Path $appHostPath) {
                (Get-ChildItem $appHostPath).LastWriteTime = Get-Date
            } 
        }
        catch {
            Write-Host "  Error downloading or extracting files: $_" -ForegroundColor Red
            Write-Host "  Please download manually from: $repoUrl/tree/$repoBranch/privatemarketplace/quickstart" -ForegroundColor Yellow
            return
        }
    }
    
    # Install Docker if missing
    $dockerNeedsInstall = $false
    if (-not $dockerInstalled) {
        Write-Host "`nInstalling Docker Desktop..." -ForegroundColor Cyan
        
        if ($wingetAvailable) {
            Write-Host "`n  ═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
            Write-Host "  Docker Desktop Installation" -ForegroundColor Yellow
            Write-Host "  ═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
            Write-Host "  ACTION REQUIRED:" -ForegroundColor Cyan
            Write-Host "  - You will be prompted to approve administrator access (UAC)" -ForegroundColor White
            Write-Host "  - Docker Desktop requires elevated privileges to install" -ForegroundColor White
            Write-Host "`n  Installation may take several minutes..." -ForegroundColor Gray
            Write-Host "  ═══════════════════════════════════════════════════════════`n" -ForegroundColor Yellow
            
            Write-Host "  Starting installation via winget..." -ForegroundColor Gray
            $wingetOutput = winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Docker Desktop installed successfully." -ForegroundColor Green
                $dockerInstalled = $true
                $dockerNeedsInstall = $true
            } elseif ($wingetOutput -match "No available upgrade found|already installed") {
                Write-Host "  Docker Desktop already installed." -ForegroundColor Green
                $dockerInstalled = $true
            } else {
                Write-Host "  Failed to install Docker Desktop via winget." -ForegroundColor Red
                Write-Host "  Please install Docker Desktop manually from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
                Write-Host "  After installation, re-run this script." -ForegroundColor Yellow
                return
            }
        } else {
            Write-Host "  winget not available. Please install Docker Desktop manually from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
            return
        }
    }
    
    # Install local .NET SDK if missing
    if (-not $dotnetInstalled) {
        Write-Host "`nInstalling .NET SDK $dotnetVersion locally..." -ForegroundColor Cyan
        
        try {
            New-DirectoryIfNeeded -Path $localDotnetPath
            
            # Download the dotnet-install script
            $dotnetInstallScript = Join-Path $env:TEMP "dotnet-install.ps1"
            $downloadSuccess = Invoke-WithProgress -Activity "Installing .NET SDK" -Status "Downloading dotnet-install script..." -ScriptBlock {
                Get-FileWithVerification -Url "https://dot.net/v1/dotnet-install.ps1" -OutFile $dotnetInstallScript
            }
            if (-not $downloadSuccess) {
                throw "Failed to download dotnet-install script"
            }
            
            # Run the installation script
            Invoke-WithProgress -Activity "Installing .NET SDK" -Status "Installing .NET SDK $dotnetVersion..." -ScriptBlock {
                & $dotnetInstallScript -Version $dotnetVersion -InstallDir $localDotnetPath -NoPath
            }
            
            # Verify installation by checking for dotnet.exe and running --list-sdks
            $localDotnetExeCheck = Join-Path $localDotnetPath "dotnet.exe"
            if (Test-Path $localDotnetExeCheck) {
                try {
                    $installedSdks = & $localDotnetExeCheck --list-sdks 2>$null
                    $matchingSdk = $installedSdks | Where-Object { $_ -match "^$([regex]::Escape($dotnetVersion))\s" }
                    
                    if ($matchingSdk) {
                        Write-Host "  .NET SDK $dotnetVersion installed successfully." -ForegroundColor Green
                        $dotnetInstalled = $true
                    } else {
                        throw "SDK version $dotnetVersion not found after installation"
                    }
                } catch {
                    throw "Failed to verify SDK installation: $_"
                }
            } else {
                throw "dotnet.exe not found after installation"
            }
            
            # Clean up
            Remove-Item $dotnetInstallScript -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Host "  Error installing .NET SDK: $_" -ForegroundColor Red
            Write-Host "  Please install manually from: https://dotnet.microsoft.com/download/dotnet/10.0" -ForegroundColor Yellow
            return
        }
    }
    
    # Install VS Code portable if missing
    if (-not $vscodeInstalled) {
        Write-Host "`nInstalling VS Code (portable)..." -ForegroundColor Cyan
        
        try {
            New-DirectoryIfNeeded -Path $localVSCodePath
            
            # Download VS Code portable ZIP
            $vscodeZipUrl = "https://update.code.visualstudio.com/latest/win32-x64-archive/stable"
            $vscodeZipPath = Join-Path $env:TEMP "vscode-portable.zip"
            
            $downloadSuccess = Invoke-WithProgress -Activity "Installing VS Code" -Status "Downloading VS Code portable..." -ScriptBlock {
                Get-FileWithVerification -Url $vscodeZipUrl -OutFile $vscodeZipPath
            }
            if (-not $downloadSuccess) {
                throw "Failed to download VS Code"
            }
            Write-Host "  VS Code downloaded successfully." -ForegroundColor Green
            
            # Extract VS Code
            Invoke-WithProgress -Activity "Installing VS Code" -Status "Extracting VS Code..." -ScriptBlock {
                Expand-Archive -Path $vscodeZipPath -DestinationPath $localVSCodePath -Force
            }
            
            # Create data directory for portable mode
            $vscodeDataPath = Join-Path $localVSCodePath "data"
            New-Item -ItemType Directory -Path $vscodeDataPath -Force | Out-Null
            
            # Clean up
            Remove-Item $vscodeZipPath -Force -ErrorAction SilentlyContinue
            
            # Verify Code.exe exists
            $vscodeExePath = Join-Path $localVSCodePath "Code.exe"
            if (Test-Path $vscodeExePath) {
                Write-Host "  VS Code installed successfully." -ForegroundColor Green
                $vscodeInstalled = $true
                
                # Prompt before launching script as admin to install administrative templates
                Write-Host "`nVS Code Administrative Templates" -ForegroundColor Cyan
                Write-Host "================================" -ForegroundColor Cyan
                Write-Host "The script needs to install VS Code Group Policy templates to the Windows" -ForegroundColor Gray
                Write-Host "PolicyDefinitions folder. This requires administrator privileges." -ForegroundColor Gray
                Write-Host "`nYou will be prompted to grant elevated access (UAC prompt).`n" -ForegroundColor Yellow
                $installTemplates = Read-Host "Do you want to install the administrative templates now? (y/n)"
                
                if ($installTemplates -eq 'y') {
                    Write-Host "  Installing VS Code administrative templates..." -ForegroundColor Gray
                    $scriptPath = $MyInvocation.MyCommand.Path
                    
                    # Log file path in root folder
                    $logFile = Join-Path $rootPath "vscode-admin-template-install.log"
                    
                    try {
                        # Launch the script with admin privileges
                        $process = Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -InstallAdminTemplates" -Verb RunAs -Wait -PassThru
                        
                        if ($process.ExitCode -eq 0) {
                            Write-Host "  Administrative templates installed successfully." -ForegroundColor Green
                        } elseif ($process.ExitCode -eq 64) {
                            Write-Host "  Warning: UAC cancelled. Templates not installed." -ForegroundColor Yellow
                        } else {
                            Write-Host "  Warning: Installation exited with code $($process.ExitCode)" -ForegroundColor Yellow
                            if (Test-Path $logFile) { Write-Host "  Log: $logFile" -ForegroundColor Gray }
                        }
                    } catch {
                        Write-Host "  Warning: Could not install templates: $_" -ForegroundColor Yellow
                        if (Test-Path $logFile) { Write-Host "  Log: $logFile" -ForegroundColor Gray }
                    }
                } else {
                    Write-Host "`n  Skipping administrative template installation." -ForegroundColor Yellow
                    Write-Host "`n  To install manually, copy the following files:" -ForegroundColor Gray
                    Write-Host "    1. Copy VSCode.admx from:" -ForegroundColor Gray
                    Write-Host "       $policiesPath\VSCode.admx" -ForegroundColor Gray
                    Write-Host "       to: C:\Windows\PolicyDefinitions\VSCode.admx" -ForegroundColor Gray
                    Write-Host "`n    2. Copy language-specific VSCode.adml files from:" -ForegroundColor Gray
                    Write-Host "       $policiesPath\<language-code>\VSCode.adml" -ForegroundColor Gray
                    Write-Host "       to: C:\Windows\PolicyDefinitions\<language-code>\VSCode.adml" -ForegroundColor Gray
                    Write-Host "       (e.g., en-us, de-de, fr-fr, etc.)`n" -ForegroundColor Gray
                }
                
                # Mark that we've already handled the admin templates prompt
                $adminTemplatesHandled = $true
            } else {
                throw "Code.exe not found after installation"
            }
        } catch {
            Write-Host "  Error installing VS Code: $_" -ForegroundColor Red
            Write-Host "  Please install manually from: https://code.visualstudio.com/" -ForegroundColor Yellow
            return
        }
    }
    
    # Install Aspire CLI locally if missing
    if (-not $aspireInstalled) {
        Write-Host "`nInstalling Aspire CLI locally..." -ForegroundColor Cyan
        
        try {
            New-DirectoryIfNeeded -Path $localAspirePath
            
            # Download and run the Aspire installation script with custom path
            $installScript = Invoke-WithProgress -Activity "Installing Aspire CLI" -Status "Downloading Aspire installation script..." -ScriptBlock {
                Invoke-WebRequest -Uri "https://aspire.dev/install.ps1" -UseBasicParsing
            }
            
            if ($installScript.StatusCode -eq 200) {
                # Save script to temp file and execute with -InstallPath parameter
                $tempScriptPath = Join-Path $env:TEMP "aspire-install.ps1"
                $installScript.Content | Out-File -FilePath $tempScriptPath -Encoding UTF8
                
                # Execute the installation script with -InstallPath parameter
                Invoke-WithProgress -Activity "Installing Aspire CLI" -Status "Installing Aspire CLI to: $localAspirePath" -ScriptBlock {
                    & $tempScriptPath -InstallPath $localAspirePath
                }
                
                # Clean up temp script
                Remove-Item $tempScriptPath -Force -ErrorAction SilentlyContinue
                
                # Verify aspire.exe exists
                $aspireExePath = Join-Path $localAspirePath "aspire.exe"
                if (Test-Path $aspireExePath) {
                    Write-Host "  Aspire CLI installed successfully." -ForegroundColor Green
                    $aspireInstalled = $true
                    
                    # Remove Aspire paths from USER PATH environment variable
                    Write-Host "  Removing Aspire from system PATH..." -ForegroundColor Gray
                    Remove-PathFromEnvironment -PathPatterns @('*\.aspire\*', '*\aspire\*')
                } else {
                    throw "aspire.exe not found after installation"
                }
            } else {
                throw "Failed to download Aspire installation script"
            }
        } catch {
            Write-Host "  Error installing Aspire CLI: $_" -ForegroundColor Red
            Write-Host "  Please install manually from: https://aspire.dev" -ForegroundColor Yellow
            return
        }
    }
    
    Write-Host "`nAll prerequisites installed successfully." -ForegroundColor Green
    
    # If Docker was just installed, inform user it will be started next
    if ($dockerNeedsInstall) {
        Write-Host "  Docker Desktop will be started automatically in the next step." -ForegroundColor Cyan
        Write-Host "  Note: First-time startup typically takes 60-90 seconds." -ForegroundColor Gray
        # Store flag for later use
        $script:dockerFirstTimeInstall = $true
    }
    
    # Re-check if admin templates are still needed after installation
    $adminTemplatesNeeded = -not (Test-AdminTemplatesInstalled)
} else {
    Write-Host "`nAll prerequisites satisfied." -ForegroundColor Green
}

# Check if VS Code is installed but admin templates are not (only if we haven't already prompted)
if ($vscodeInstalled -and -not $adminTemplatesHandled -and -not (Test-AdminTemplatesInstalled)) {
    Write-Host "`nVS Code Administrative Templates Not Installed" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "The VS Code Group Policy templates are not currently installed." -ForegroundColor Gray
    Write-Host "These templates are required to configure the private marketplace." -ForegroundColor Gray
    Write-Host "`nYou will be prompted to grant elevated access (UAC prompt).`n" -ForegroundColor Yellow
    $installTemplates = Read-Host "Do you want to install the administrative templates now? (y/n)"
    
    if ($installTemplates -eq 'y') {
        Write-Host "  Installing VS Code administrative templates..." -ForegroundColor Gray
        $scriptPath = $MyInvocation.MyCommand.Path
        
        # Log file path in root folder
        $logFile = Join-Path $rootPath "vscode-admin-template-install.log"
        
        try {
            # Launch the script with admin privileges
            $process = Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -InstallAdminTemplates" -Verb RunAs -Wait -PassThru
            
            if ($process.ExitCode -eq 0) {
                Write-Host "  Administrative templates installed successfully." -ForegroundColor Green
            } elseif ($process.ExitCode -eq 64) {
                Write-Host "  Warning: UAC cancelled. Templates not installed." -ForegroundColor Yellow
                Write-Host "  The private marketplace may not work correctly without these templates." -ForegroundColor Yellow
            } else {
                Write-Host "  Warning: Installation exited with code $($process.ExitCode)" -ForegroundColor Yellow
                if (Test-Path $logFile) { Write-Host "  Log: $logFile" -ForegroundColor Gray }
            }
        } catch {
            Write-Host "  Warning: Could not install templates: $_" -ForegroundColor Yellow
            if (Test-Path $logFile) { Write-Host "  Log: $logFile" -ForegroundColor Gray }
        }
    } else {
        Write-Host "`n  Skipping administrative template installation." -ForegroundColor Yellow
        Write-Host "  Note: You can run this script again later to install the templates." -ForegroundColor Gray
    }
}

# Save the original directory
$originalDirectory = Get-Location

# Navigate to the quickstart folder
Write-Host "`nNavigating to quickstart folder..." -ForegroundColor Cyan

if (-not (Test-Path $rootPath)) {
    Write-Host "Error: quickstart folder not found!" -ForegroundColor Red
    return
}

Set-Location $rootPath
Write-Host "Current directory: $(Get-Location)" -ForegroundColor Gray

# Set up local .NET SDK environment
Write-Host "`nConfiguring local .NET SDK environment..." -ForegroundColor Cyan
$localDotnetExe = Join-Path $localDotnetPath "dotnet.exe"

if (Test-Path $localDotnetExe) {
    # Set environment variables to use local .NET
    $env:DOTNET_ROOT = $localDotnetPath
    $env:DOTNET_MULTILEVEL_LOOKUP = "0"  # Prevent looking in global locations
    $env:PATH = "$localDotnetPath;$env:PATH"
    
    Write-Host "  DOTNET_ROOT set to: $localDotnetPath" -ForegroundColor Gray
    Write-Host "  Local .NET version: " -NoNewline -ForegroundColor Gray
    & $localDotnetExe --version
    
    # Verify SDK is available
    $localSdks = & $localDotnetExe --list-sdks 2>$null
    if ($localSdks -match $dotnetVersion) {
        Write-Host "  Local .NET SDK $dotnetVersion is ready." -ForegroundColor Green
    } else {
        Write-Host "  Warning: Expected SDK version $dotnetVersion not found in local installation." -ForegroundColor Yellow
    }
} else {
    Write-Host "  Error: Local .NET SDK executable not found at: $localDotnetExe" -ForegroundColor Red
    return
}

# Ensure Docker is running
Write-Host "`nChecking Docker engine status..." -ForegroundColor Cyan
$dockerEngineRunning = $false
try {
    $null = docker info 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Docker engine is running." -ForegroundColor Green
        $dockerEngineRunning = $true
    } else {
        throw "Docker engine not responding"
    }
} catch {
    Write-Host "  Docker engine is not running." -ForegroundColor Yellow
}

if (-not $dockerEngineRunning) {
    # Try to start Docker Desktop
    $dockerDesktopPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerDesktopPath) {
        Write-Host "  Starting Docker Desktop..." -ForegroundColor Cyan
        
        # Check if Docker Desktop is already running (process exists)
        $dockerProcess = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
        if (-not $dockerProcess) {
            Start-Process -FilePath $dockerDesktopPath
            Write-Host "  Docker Desktop started. Waiting for engine to be ready..." -ForegroundColor Gray
        } else {
            Write-Host "  Docker Desktop is running but engine not ready. Waiting..." -ForegroundColor Gray
        }
        
        # Refresh PATH environment variable to pick up Docker if it was just installed
        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $env:PATH = "$machinePath;$userPath"
        
        # Provide context-appropriate message
        if ($script:dockerFirstTimeInstall) {
            Write-Host "`n  ═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
            Write-Host "  Docker Desktop First-Time Setup" -ForegroundColor Yellow
            Write-Host "  ═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
            Write-Host "  Docker Desktop is starting for the first time." -ForegroundColor Gray
            Write-Host "  This typically takes 60-90 seconds." -ForegroundColor Gray
            Write-Host "`n  ACTION REQUIRED:" -ForegroundColor Cyan
            Write-Host "  - Accept the Docker Desktop Service Agreement when prompted" -ForegroundColor White
            Write-Host "  - Complete any additional setup steps in the Docker Desktop window" -ForegroundColor White
            Write-Host "`n  The script will wait for Docker to be ready..." -ForegroundColor Gray
            Write-Host "  ═══════════════════════════════════════════════════════════`n" -ForegroundColor Yellow
        }
        
        # Wait for Docker to be ready using helper function
        $dockerReady = Wait-ForCondition -Condition {
            $output = docker info 2>&1 | Out-String
            # Docker is ready when output contains server info and no connection errors
            return ($output -match 'Server:' -and $output -notmatch 'failed to connect')
        } -TimeoutSeconds $Config.MaxDockerWaitTime -IntervalSeconds $Config.DockerCheckInterval -StatusMessage "Waiting for Docker engine"
        
        if ($dockerReady) {
            Write-Host "  Docker engine is now running." -ForegroundColor Green
        } else {
            Write-Host "  Docker engine did not start within $($Config.MaxDockerWaitTime) seconds." -ForegroundColor Yellow
            
            # Check if Docker Desktop is still starting
            $dockerProcess = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
            if ($dockerProcess) {
                Write-Host "  Docker Desktop is still initializing in the background." -ForegroundColor Gray
                Write-Host "  Please wait a bit longer for it to complete startup, then re-run this script." -ForegroundColor Yellow
            } else {
                Write-Host "  Docker Desktop may have encountered an issue during startup." -ForegroundColor Gray
                Write-Host "  Please start Docker Desktop manually and re-run this script." -ForegroundColor Yellow
            }
            return
        }
    } else {
        Write-Host "  Docker Desktop not found at expected location." -ForegroundColor Red
        Write-Host "  Please start Docker Desktop manually and run this script again." -ForegroundColor Yellow
        return
    }
}

# Run quickstart using local installation of aspire
Write-Host "`nRunning quickstart..." -ForegroundColor Cyan
try {
    # Use the local Aspire executable
    $aspireExePath = Join-Path $localAspirePath "aspire.exe"
    
    # Verify environment is still configured
    Write-Host "  Using .NET SDK: $($env:DOTNET_ROOT)" -ForegroundColor Gray
    Write-Host "  .NET version: " -NoNewline -ForegroundColor Gray
    & $localDotnetExe --version
    
    Write-Host "`n  ═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  Aspire Dashboard SSL Certificate Setup" -ForegroundColor Yellow
    Write-Host "  ═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  On first run, Aspire will configure a local SSL certificate" -ForegroundColor Gray
    Write-Host "  for secure HTTPS access to the dashboard." -ForegroundColor Gray
    Write-Host "`n  ACTION REQUIRED (if prompted):" -ForegroundColor Cyan
    Write-Host "  - Click 'Yes' to trust the ASP.NET Core HTTPS development certificate" -ForegroundColor White
    Write-Host "  - This is a one-time setup for secure local development" -ForegroundColor White
    Write-Host "  - The certificate is only trusted on this computer" -ForegroundColor White
    Write-Host "`n  Starting Aspire dashboard..." -ForegroundColor Gray
    Write-Host "  ═══════════════════════════════════════════════════════════`n" -ForegroundColor Yellow
    
    # Launch Aspire with explicit environment variables to ensure it uses local .NET
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $aspireExePath
    $psi.Arguments = "run --non-interactive"
    $psi.UseShellExecute = $false
    $psi.WorkingDirectory = $rootPath
    $psi.EnvironmentVariables["DOTNET_ROOT"] = $localDotnetPath
    $psi.EnvironmentVariables["DOTNET_MULTILEVEL_LOOKUP"] = "0"
    $psi.EnvironmentVariables["PATH"] = "$localDotnetPath;$($env:PATH)"
    
    $process = [System.Diagnostics.Process]::Start($psi)
    $process.WaitForExit()
}
catch {
    Write-Host "Error running quickstart: $_" -ForegroundColor Red
}
finally {
    # Return to original directory
    Set-Location $originalDirectory
    
    # Prompt to clean up temp folder
    Write-Host "`n" -ForegroundColor Cyan
    Write-Host "Quickstart has exited." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "IMPORTANT: Unset the Extension Gallery Service URL Policy" -ForegroundColor Yellow
    Write-Host "===========================================" -ForegroundColor Yellow
    Write-Host "To restore normal VS Code Marketplace access, you need to unset the" -ForegroundColor Gray
    Write-Host "'Extension Gallery Service URL' Group Policy setting:" -ForegroundColor Gray
    Write-Host "  1. Open Group Policy Editor (gpedit.msc)" -ForegroundColor Gray
    Write-Host "  2. Navigate to: User Configuration > Administrative Templates > Visual Studio Code > Extensions" -ForegroundColor Gray
    Write-Host "  3. Set 'Extension Gallery Service URL' to 'Not Configured'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Temporary files location: $rootPath" -ForegroundColor Gray
    Write-Host ""
    $cleanupResponse = Read-Host "Do you want to remove the temporary folder and all its contents? (y/n)"
    
    if ($cleanupResponse -eq 'y') {
        # Prompt to uninstall Docker if it was installed by this script (before removing files)
        $uninstallDocker = $false
        if ($script:dockerFirstTimeInstall) {
            Write-Host "`nDocker Desktop Uninstallation" -ForegroundColor Cyan
            Write-Host "=============================" -ForegroundColor Cyan
            Write-Host "This script installed Docker Desktop earlier." -ForegroundColor Gray
            Write-Host ""
            $dockerResponse = Read-Host "Do you want to uninstall Docker Desktop? (y/n)"
            $uninstallDocker = ($dockerResponse -eq 'y')
        }
        
        # Uninstall Docker before removing files (if requested)
        if ($uninstallDocker) {
            Write-Host "`nUninstalling Docker Desktop..." -ForegroundColor Yellow
            
            # Check if winget is available
            if ($null -ne (Get-Command winget -ErrorAction SilentlyContinue)) {
                try {
                    Write-Host "  Using winget to uninstall Docker Desktop..." -ForegroundColor Gray
                    $null = winget uninstall -e --id Docker.DockerDesktop --silent 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  Docker Desktop uninstalled successfully." -ForegroundColor Green
                    } else {
                        Write-Host "  Warning: Uninstall may have encountered issues." -ForegroundColor Yellow
                        Write-Host "  You can uninstall manually via Windows Settings > Apps" -ForegroundColor Gray
                    }
                } catch {
                    Write-Host "  Error uninstalling Docker Desktop: $_" -ForegroundColor Red
                    Write-Host "  You can uninstall manually via Windows Settings > Apps" -ForegroundColor Gray
                }
            } else {
                Write-Host "  winget not available." -ForegroundColor Yellow
                Write-Host "  Please uninstall Docker Desktop manually via Windows Settings > Apps" -ForegroundColor Gray
            }
        } elseif ($script:dockerFirstTimeInstall) {
            Write-Host "`nDocker Desktop will remain installed on your system." -ForegroundColor Gray
        }
        
        Write-Host "`nRemoving temporary folder..." -ForegroundColor Yellow
        
        # Track cleanup failures
        $cleanupErrors = @()
        
        # Navigate to user profile folder before removing temp folder if we're currently in it
        try {
            $currentLocation = (Get-Location).Path
            if ($currentLocation.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)) {
                Set-Location $env:USERPROFILE
                Write-Host "Navigated to profile folder: $env:USERPROFILE" -ForegroundColor Gray
            }
        } catch {
            Write-Host "Warning: Could not navigate to profile folder: $_" -ForegroundColor Yellow
            $cleanupErrors += "Failed to navigate to profile folder"
        }
        
        # Wait for processes to exit
        Write-Host "Waiting for processes to exit..." -ForegroundColor Gray
        Start-Sleep -Seconds 3
        
        # Remove temporary folder
        try {
            if (Test-Path $rootPath) {
                Remove-Item -Path $rootPath -Recurse -Force -ErrorAction Stop
                Write-Host "Temporary folder removed successfully." -ForegroundColor Green
            } else {
                Write-Host "Temporary folder not found." -ForegroundColor Gray
            }
        } catch {
            Write-Host "Error removing temporary folder: $_" -ForegroundColor Red
            $cleanupErrors += "Failed to remove temporary folder: $_"
        }
        
        # Display cleanup summary
        if ($cleanupErrors.Count -gt 0) {
            Write-Host "`nSome cleanup operations failed:" -ForegroundColor Yellow
            foreach ($err in $cleanupErrors) {
                Write-Host "  - $err" -ForegroundColor Yellow
            }
            Write-Host "You can manually delete: $rootPath" -ForegroundColor Yellow
        }
        
        # Remove administrative templates if they were installed
        if (Test-AdminTemplatesInstalled) {
            Write-Host "`nVS Code Administrative Templates Removal" -ForegroundColor Cyan
            Write-Host "=========================================" -ForegroundColor Cyan
            Write-Host "The VS Code Group Policy templates are currently installed." -ForegroundColor Gray
            Write-Host "Removing them requires administrator privileges." -ForegroundColor Gray
            Write-Host "`nYou will be prompted to grant elevated access (UAC prompt).`n" -ForegroundColor Yellow
            $removeTemplates = Read-Host "Do you want to remove the administrative templates? (y/n)"
            
            if ($removeTemplates -eq 'y') {
                Write-Host "  Removing VS Code administrative templates..." -ForegroundColor Gray
                $scriptPath = $MyInvocation.MyCommand.Path
                
                try {
                    # Launch the script with admin privileges
                    $process = Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -RemoveAdminTemplates" -Verb RunAs -Wait -PassThru
                    
                    if ($process.ExitCode -eq 0) {
                        Write-Host "  Administrative templates removed successfully." -ForegroundColor Green
                    } elseif ($process.ExitCode -eq 64) {
                        Write-Host "  Warning: UAC cancelled. Templates not removed." -ForegroundColor Yellow
                    } else {
                        Write-Host "  Warning: Removal exited with code $($process.ExitCode)" -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "  Warning: Could not remove templates: $_" -ForegroundColor Yellow
                    Write-Host "  You can remove them manually from: $env:WINDIR\PolicyDefinitions" -ForegroundColor Gray
                }
            } else {
                Write-Host "`n  Administrative templates will remain installed." -ForegroundColor Gray
                Write-Host "  You can remove them manually from: $env:WINDIR\PolicyDefinitions" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "`nTemporary folder preserved at: $rootPath" -ForegroundColor Green
        Write-Host "`nTo run the Private Marketplace again:" -ForegroundColor Cyan
        Write-Host "  1. Open PowerShell" -ForegroundColor Gray
        Write-Host "  2. Run: & \"$rootPath\Run-PrivateMarketplace.ps1\"" -ForegroundColor Gray
        Write-Host ""
    }
}
