# PowerShell script to download and run the VS Marketplace repository

$ErrorActionPreference = "Stop"

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# If -InstallAdminTemplates parameter is passed, only install templates and exit
if ($args -contains "-InstallAdminTemplates") {
    if (-not $isAdmin) {
        Write-Host "Error: Must run as administrator to install administrative templates." -ForegroundColor Red
        exit 1
    }
    
    # Determine paths based on script location
    $rootPath = Join-Path $env:TEMP "privatemarketplace-quickstart"
    $vscodePolicyPath = Join-Path $rootPath "policies"
    
    # Set up logging in root folder
    $logFile = Join-Path $rootPath "vscode-admin-template-install.log"
    $errorLogFile = "$logFile.err"
    
    # Start transcript to capture all output
    Start-Transcript -Path $logFile -Force
    
    Write-Host "Installing VS Code administrative templates..." -ForegroundColor Cyan
    Write-Host "Root path: $rootPath" -ForegroundColor Gray
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
            Write-Host "Checking if policies folder exists..." -ForegroundColor Gray
            if (Test-Path $vscodePolicyPath) {
                Write-Host "Policies folder exists. Contents:" -ForegroundColor Gray
                Get-ChildItem -Path $vscodePolicyPath | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Gray }
            } else {
                Write-Host "Policies folder does not exist at: $vscodePolicyPath" -ForegroundColor Red
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
        exit 1
    }
}

Write-Host "Private Marketplace for VS Code Quickstart" -ForegroundColor Cyan

# Check and install prerequisites
Write-Host "`nChecking prerequisites..." -ForegroundColor Cyan

# Initialize tracking variables
$missingPrereqs = @()
$dockerInstalled = $false
$vscodeInstalled = $false
$aspireInstalled = $false
$dotnetInstalled = $false
$repoExists = $false
$wingetAvailable = $false

# Define repository details
$repoUrl = "https://github.com/mcumming/vsmarketplace"
$repoBranch = "main"  # Change this to test different branches
$rootPath = Join-Path $env:TEMP "privatemarketplace-quickstart"
$dotnetVersion = "10.0.100"  # Version of .NET to install locally

# Define paths for local installations
$localVSCodePath = Join-Path $rootPath ".vscode"
$localAspirePath = Join-Path $rootPath ".aspire"
$localDotnetPath = Join-Path $rootPath ".dotnet"
$policiesPath = Join-Path $rootPath "policies"

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
    Write-Host "  Docker not found" -ForegroundColor Yellow
    $missingPrereqs += @{
        Name = "Docker Desktop"
        InstallMethod = "winget"
        ManualUrl = "https://www.docker.com/products/docker-desktop"
    }
}

# Check VS Code
Write-Host "Checking for VS Code..." -ForegroundColor Gray

# Check if root doesn't exist, VS Code can't exist either
if (-not (Test-Path $rootPath)) {
    Write-Host "  VS Code not found (quickstart folder not present)" -ForegroundColor Yellow
    $missingPrereqs += @{
        Name = "VS Code (portable)"
        InstallMethod = "vscode-local"
        InstallPath = $localVSCodePath
        ManualUrl = "https://code.visualstudio.com/"
    }
} else {
    $vscodeExePath = Join-Path $localVSCodePath "Code.exe"
    
    if (Test-Path $vscodeExePath) {
        Write-Host "  VS Code found at: $localVSCodePath" -ForegroundColor Green
        $vscodeInstalled = $true
    } else {
        Write-Host "  VS Code not found" -ForegroundColor Yellow
        $missingPrereqs += @{
            Name = "VS Code (portable)"
            InstallMethod = "vscode-local"
            InstallPath = $localVSCodePath
            ManualUrl = "https://code.visualstudio.com/"
        }
    }
}

# Check Aspire CLI (local installation)
Write-Host "Checking for Aspire CLI..." -ForegroundColor Gray

# If root doesn't exist, Aspire can't exist either
if (-not (Test-Path $rootPath)) {
    Write-Host "  Aspire CLI not found (quickstart folder not present)" -ForegroundColor Yellow
    $missingPrereqs += @{
        Name = "Aspire CLI (version 13+)"
        InstallMethod = "aspire-local"
        InstallPath = $localAspirePath
        ManualUrl = "https://learn.microsoft.com/dotnet/aspire"
    }
} else {
    $aspireExePath = Join-Path $localAspirePath "aspire.exe"
    
    if (Test-Path $aspireExePath) {
        Write-Host "  Aspire CLI found at: $localAspirePath" -ForegroundColor Green
        $aspireInstalled = $true
    } else {
        Write-Host "  Aspire CLI not found" -ForegroundColor Yellow
        $missingPrereqs += @{
            Name = "Aspire CLI (version 13+)"
            InstallMethod = "aspire-local"
            InstallPath = $localAspirePath
            ManualUrl = "https://learn.microsoft.com/dotnet/aspire"
        }
    }
}

# Check for local .NET SDK installation
Write-Host "Checking for local .NET SDK..." -ForegroundColor Gray

# If root doesn't exist, .NET SDK can't exist either
if (-not (Test-Path $rootPath)) {
    Write-Host "  Local .NET SDK not found (quickstart folder not present)" -ForegroundColor Yellow
    $missingPrereqs += @{
        Name = ".NET SDK $dotnetVersion (local)"
        InstallMethod = "dotnet-install"
        Version = $dotnetVersion
        InstallPath = $localDotnetPath
        ManualUrl = "https://dotnet.microsoft.com/download/dotnet/10.0"
    }
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
                Write-Host "  Local .NET installation found, but version $dotnetVersion is missing" -ForegroundColor Yellow
                Write-Host "  Installed SDKs:" -ForegroundColor Gray
                $installedSdks | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
                $missingPrereqs += @{
                    Name = ".NET SDK $dotnetVersion (local)"
                    InstallMethod = "dotnet-install"
                    Version = $dotnetVersion
                    InstallPath = $localDotnetPath
                    ManualUrl = "https://dotnet.microsoft.com/download/dotnet/10.0"
                }
            }
        } catch {
            Write-Host "  Error checking local .NET SDK: $_" -ForegroundColor Yellow
            $missingPrereqs += @{
                Name = ".NET SDK $dotnetVersion (local)"
                InstallMethod = "dotnet-install"
                Version = $dotnetVersion
                InstallPath = $localDotnetPath
                ManualUrl = "https://dotnet.microsoft.com/download/dotnet/10.0"
            }
        }
    } else {
        Write-Host "  Local .NET SDK not found" -ForegroundColor Yellow
        $missingPrereqs += @{
            Name = ".NET SDK $dotnetVersion (local)"
            InstallMethod = "dotnet-install"
            Version = $dotnetVersion
            InstallPath = $localDotnetPath
            ManualUrl = "https://dotnet.microsoft.com/download/dotnet/10.0"
        }
    }
}

# Check for aspire files
Write-Host "Checking for aspire files..." -ForegroundColor Gray
if (Test-Path $rootPath) {
    # Verify key files exist
    $apphostPath = Join-Path $rootPath "apphost.cs"
    if (Test-Path $apphostPath) {
        Write-Host "  Aspire files found at: $rootPath" -ForegroundColor Green
        $repoExists = $true
    } else {
        Write-Host "  Folder exists but appears incomplete" -ForegroundColor Yellow
        $missingPrereqs += @{
            Name = "Aspire Files"
            InstallMethod = "download"
            DownloadMethod = "ZIP download"
            TargetFolder = $rootPath
            ManualUrl = $repoUrl
        }
    }
} else {
    Write-Host "  Aspire files not found" -ForegroundColor Yellow
    $missingPrereqs += @{
        Name = "Aspire Files"
        InstallMethod = "download"
        DownloadMethod = "ZIP download"
        TargetFolder = $rootPath
        ManualUrl = $repoUrl
    }
}

# Check winget availability
$wingetAvailable = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)

# Display summary if prerequisites are missing
if ($missingPrereqs.Count -gt 0) {
    Write-Host "`n=== Missing Prerequisites ===" -ForegroundColor Yellow
    foreach ($prereq in $missingPrereqs) {
        Write-Host "  - $($prereq.Name)" -ForegroundColor Yellow
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
    
    # Prompt for confirmation
    Write-Host ""
    $response = Read-Host "Do you want to proceed with installation? (y/n)"
    if ($response -ne 'y') {
        Write-Host "Installation cancelled by user. Please install the missing prerequisites and run this script again." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n=== Installing Prerequisites ===" -ForegroundColor Cyan
    
    # Download aspire files if missing
    if (-not $repoExists) {
        Write-Host "`nDownloading aspire files..." -ForegroundColor Cyan
        
        # Create root directory
        if (-not (Test-Path $rootPath)) {
            New-Item -ItemType Directory -Path $rootPath -Force | Out-Null
        }
        
        # Download only the privatemarketplace/quickstart folder
        Write-Host "  Downloading from repository (branch: $repoBranch)..." -ForegroundColor Gray
        $zipUrl = "$repoUrl/archive/refs/heads/$repoBranch.zip"
        $tempZipPath = Join-Path $env:TEMP "vsmarketplace-$repoBranch.zip"
        
        try {
            Invoke-WebRequest -Uri $zipUrl -OutFile $tempZipPath -UseBasicParsing
            Write-Host "  ZIP downloaded successfully." -ForegroundColor Green
            
            Write-Host "  Extracting aspire files..." -ForegroundColor Gray
            $tempExtractPath = Join-Path $env:TEMP "vsmarketplace-extract"
            if (Test-Path $tempExtractPath) {
                Remove-Item -Path $tempExtractPath -Recurse -Force
            }
            Expand-Archive -Path $tempZipPath -DestinationPath $tempExtractPath -Force
            
            # Copy aspire folder contents directly to root (excluding .dotnet, .aspire, .vscode)
            $extractedAspireFolder = Join-Path $tempExtractPath "vsmarketplace-$repoBranch\privatemarketplace\quickstart\aspire"
            if (Test-Path $extractedAspireFolder) {
                # Get all items in aspire folder except hidden tool folders
                Get-ChildItem -Path $extractedAspireFolder | Where-Object { 
                    $_.Name -notin @('.dotnet', '.aspire', '.vscode')
                } | ForEach-Object {
                    Copy-Item -Path $_.FullName -Destination $rootPath -Recurse -Force
                }
                Write-Host "  Aspire files copied successfully." -ForegroundColor Green
            } else {
                throw "Aspire folder not found in downloaded archive"
            }
            
            # Clean up temporary files
            Remove-Item -Path $tempZipPath -Force
            Remove-Item -Path $tempExtractPath -Recurse -Force
            Write-Host "  Download complete." -ForegroundColor Green
            $repoExists = $true
        }
        catch {
            Write-Host "  Error downloading or extracting files: $_" -ForegroundColor Red
            Write-Host "  Please download manually from: $repoUrl/tree/$repoBranch/privatemarketplace/quickstart" -ForegroundColor Yellow
            return
        }
    }
    
    # Install Docker if missing
    if (-not $dockerInstalled) {
        Write-Host "`nInstalling Docker Desktop..." -ForegroundColor Cyan
        
        if ($wingetAvailable) {
            Write-Host "  Using winget to install Docker Desktop..." -ForegroundColor Gray
            winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Docker Desktop installed successfully." -ForegroundColor Green
                Write-Host "  IMPORTANT: Please start Docker Desktop and wait for it to be ready, then re-run this script." -ForegroundColor Yellow
                return
            } else {
                Write-Host "  Failed to install Docker Desktop via winget." -ForegroundColor Red
                Write-Host "  Please install Docker Desktop manually from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
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
            # Create the local dotnet directory
            if (-not (Test-Path $localDotnetPath)) {
                New-Item -ItemType Directory -Path $localDotnetPath -Force | Out-Null
                Write-Host "  Created directory: $localDotnetPath" -ForegroundColor Gray
            }
            
            # Download the dotnet-install script
            Write-Host "  Downloading dotnet-install script..." -ForegroundColor Gray
            $dotnetInstallScript = Join-Path $env:TEMP "dotnet-install.ps1"
            Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $dotnetInstallScript -UseBasicParsing
            
            # Run the installation script
            Write-Host "  Installing .NET SDK $dotnetVersion to $localDotnetPath..." -ForegroundColor Gray
            & $dotnetInstallScript -Version $dotnetVersion -InstallDir $localDotnetPath -NoPath
            
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
            # Create the local VS Code directory
            if (-not (Test-Path $localVSCodePath)) {
                New-Item -ItemType Directory -Path $localVSCodePath -Force | Out-Null
                Write-Host "  Created directory: $localVSCodePath" -ForegroundColor Gray
            }
            
            # Download VS Code portable ZIP
            Write-Host "  Downloading VS Code portable..." -ForegroundColor Gray
            $vscodeZipUrl = "https://update.code.visualstudio.com/latest/win32-x64-archive/stable"
            $vscodeZipPath = Join-Path $env:TEMP "vscode-portable.zip"
            
            Invoke-WebRequest -Uri $vscodeZipUrl -OutFile $vscodeZipPath -UseBasicParsing
            Write-Host "  VS Code downloaded successfully." -ForegroundColor Green
            
            # Extract VS Code
            Write-Host "  Extracting VS Code..." -ForegroundColor Gray
            Expand-Archive -Path $vscodeZipPath -DestinationPath $localVSCodePath -Force
            
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
                Write-Host ""
                Write-Host "VS Code Administrative Templates" -ForegroundColor Cyan
                Write-Host "================================" -ForegroundColor Cyan
                Write-Host "The script needs to install VS Code Group Policy templates to the Windows" -ForegroundColor Gray
                Write-Host "PolicyDefinitions folder. This requires administrator privileges." -ForegroundColor Gray
                Write-Host ""
                Write-Host "You will be prompted to grant elevated access (UAC prompt)." -ForegroundColor Yellow
                Write-Host ""
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
                        } else {
                            Write-Host "    Warning: Administrative template installation exited with code $($process.ExitCode)" -ForegroundColor Yellow
                        }
                        
                        # Display log file location for debugging
                        if (Test-Path $logFile) {
                            Write-Host "    Installation log: $logFile" -ForegroundColor Gray
                        }
                        if (Test-Path "$logFile.err") {
                            Write-Host "    Error log: $logFile.err" -ForegroundColor Gray
                        }
                    } catch {
                        Write-Host "    Warning: Could not install administrative templates: $_" -ForegroundColor Yellow
                        if (Test-Path $logFile) {
                            Write-Host "    Log file: $logFile" -ForegroundColor Gray
                        }
                    }
                } else {
                    Write-Host ""
                    Write-Host "  Skipping administrative template installation." -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "  To install manually, copy the following files:" -ForegroundColor Gray
                    Write-Host "    1. Copy VSCode.admx from:" -ForegroundColor Gray
                    Write-Host "       $policiesPath\VSCode.admx" -ForegroundColor Gray
                    Write-Host "       to: C:\Windows\PolicyDefinitions\VSCode.admx" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "    2. Copy language-specific VSCode.adml files from:" -ForegroundColor Gray
                    Write-Host "       $policiesPath\<language-code>\VSCode.adml" -ForegroundColor Gray
                    Write-Host "       to: C:\Windows\PolicyDefinitions\<language-code>\VSCode.adml" -ForegroundColor Gray
                    Write-Host "       (e.g., en-us, de-de, fr-fr, etc.)" -ForegroundColor Gray
                    Write-Host ""
                }
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
            # Create the local aspire directory
            if (-not (Test-Path $localAspirePath)) {
                New-Item -ItemType Directory -Path $localAspirePath -Force | Out-Null
                Write-Host "  Created directory: $localAspirePath" -ForegroundColor Gray
            }
            
            # Download and run the Aspire installation script with custom path
            Write-Host "  Downloading Aspire installation script..." -ForegroundColor Gray
            $installScript = Invoke-WebRequest -Uri "https://aspire.dev/install.ps1" -UseBasicParsing
            
            if ($installScript.StatusCode -eq 200) {
                Write-Host "  Installing Aspire CLI to: $localAspirePath" -ForegroundColor Gray
                
                # Save script to temp file and execute with -InstallPath parameter
                $tempScriptPath = Join-Path $env:TEMP "aspire-install.ps1"
                $installScript.Content | Out-File -FilePath $tempScriptPath -Encoding UTF8
                
                # Execute the installation script with -InstallPath parameter
                & $tempScriptPath -InstallPath $localAspirePath
                
                # Clean up temp script
                Remove-Item $tempScriptPath -Force -ErrorAction SilentlyContinue
                
                # Verify aspire.exe exists
                $aspireExePath = Join-Path $localAspirePath "aspire.exe"
                if (Test-Path $aspireExePath) {
                    Write-Host "  Aspire CLI installed successfully." -ForegroundColor Green
                    $aspireInstalled = $true
                    
                    # Remove Aspire paths from USER PATH environment variable
                    Write-Host "  Removing Aspire from system PATH..." -ForegroundColor Gray
                    try {
                        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
                        if ($userPath) {
                            # Split path into components and filter out any Aspire-related paths
                            $pathComponents = $userPath -split ';' | Where-Object { 
                                $_ -and $_ -notmatch '\\\.aspire\\' -and $_ -notmatch '\\aspire\\' 
                            }
                            $newPath = $pathComponents -join ';'
                            
                            # Only update if there were changes
                            if ($userPath -ne $newPath) {
                                [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
                                Write-Host "  Aspire paths removed from user PATH." -ForegroundColor Green
                            } else {
                                Write-Host "  No Aspire paths found in user PATH." -ForegroundColor Gray
                            }
                        }
                    } catch {
                        Write-Host "  Warning: Could not clean PATH environment variable: $_" -ForegroundColor Yellow
                    }
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
} else {
    Write-Host "`nAll prerequisites satisfied." -ForegroundColor Green
}

# Save the original directory
$originalDirectory = Get-Location

# Navigate to the aspire folder
Write-Host "`nNavigating to aspire folder..." -ForegroundColor Cyan

if (-not (Test-Path $rootPath)) {
    Write-Host "Error: aspire folder not found!" -ForegroundColor Red
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
try {
    $dockerInfo = docker info 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Docker engine is running." -ForegroundColor Green
    } else {
        throw "Docker engine not responding"
    }
} catch {
    Write-Host "  Docker engine is not running. Starting Docker Desktop..." -ForegroundColor Yellow
    
    # Try to start Docker Desktop
    $dockerDesktopPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerDesktopPath) {
        Start-Process -FilePath $dockerDesktopPath
        Write-Host "  Waiting for Docker engine to start..." -ForegroundColor Gray
        
        # Wait for Docker to be ready (max 60 seconds)
        $maxWaitTime = 60
        $waitedTime = 0
        $dockerReady = $false
        
        while ($waitedTime -lt $maxWaitTime) {
            Start-Sleep -Seconds 2
            $waitedTime += 2
            
            try {
                $dockerInfo = docker info 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $dockerReady = $true
                    break
                }
            } catch {
                # Continue waiting
            }
            
            Write-Host "  Still waiting... ($waitedTime seconds)" -ForegroundColor Gray
        }
        
        if ($dockerReady) {
            Write-Host "  Docker engine is now running." -ForegroundColor Green
        } else {
            Write-Host "  Docker engine did not start within $maxWaitTime seconds." -ForegroundColor Yellow
            Write-Host "  Please ensure Docker Desktop is running and try again." -ForegroundColor Yellow
            return
        }
    } else {
        Write-Host "  Docker Desktop not found at expected location." -ForegroundColor Red
        Write-Host "  Please start Docker Desktop manually and run this script again." -ForegroundColor Yellow
        return
    }
}

# Run aspire using local installation
Write-Host "`nRunning aspire..." -ForegroundColor Cyan
try {
    # Use the local Aspire executable
    $aspireExePath = Join-Path $localAspirePath "aspire.exe"
    & $aspireExePath run --non-interactive
}
catch {
    Write-Host "Error running aspire: $_" -ForegroundColor Red
}
finally {
    # Return to original directory
    Set-Location $originalDirectory
    
    # Prompt to clean up temp folder
    Write-Host "`n" -ForegroundColor Cyan
    Write-Host "Aspire has exited." -ForegroundColor Cyan
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
        Write-Host "Removing temporary folder..." -ForegroundColor Yellow
        
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
            Write-Host ""
            Write-Host "Some cleanup operations failed:" -ForegroundColor Yellow
            foreach ($error in $cleanupErrors) {
                Write-Host "  - $error" -ForegroundColor Yellow
            }
            Write-Host "You can manually delete: $rootPath" -ForegroundColor Yellow
        }
    } else {
        Write-Host ""
        Write-Host "Temporary folder preserved at: $rootPath" -ForegroundColor Green
        Write-Host ""
        Write-Host "To run the Private Marketplace again:" -ForegroundColor Cyan
        Write-Host "  1. Open PowerShell" -ForegroundColor Gray
        Write-Host "  2. Run: & \"$rootPath\Run-PrivateMarketplace.ps1\"" -ForegroundColor Gray
        Write-Host ""
    }
}
