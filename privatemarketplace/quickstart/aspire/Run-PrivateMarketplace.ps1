# PowerShell script to download and run the VS Marketplace repository

param(
    [string]$Path = "./vsmarketplace"
)

$ErrorActionPreference = "Stop"

Write-Host "Private Marketplace for VS Code Quickstart" -ForegroundColor Cyan

# Check and install prerequisites
Write-Host "`nChecking prerequisites..." -ForegroundColor Cyan

# Initialize tracking variables
$missingPrereqs = @()
$dockerInstalled = $false
$aspireInstalled = $false
$dotnetInstalled = $false
$repoExists = $false
$wingetAvailable = $false

# Define repository details
$repoUrl = "https://github.com/mcumming/vsmarketplace"
$repoBranch = "main"  # Change this to test different branches
$repoPath = $Path
$dotnetVersion = "10.0.100"  # Version of .NET to install locally

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

# Check Aspire CLI
Write-Host "Checking for Aspire CLI..." -ForegroundColor Gray
try {
    $aspireVersionOutput = aspire --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        # Extract version number (format: "13.0.0" or similar)
        if ($aspireVersionOutput -match '(\d+)\.(\d+)\.(\d+)') {
            $majorVersion = [int]$matches[1]
            if ($majorVersion -ge 13) {
                Write-Host "  Aspire CLI detected: $aspireVersionOutput" -ForegroundColor Green
                $aspireInstalled = $true
            } else {
                Write-Host "  Aspire CLI version $aspireVersionOutput found, but version 13+ required" -ForegroundColor Yellow
                throw "Aspire CLI version too old"
            }
        } else {
            Write-Host "  Aspire CLI detected: $aspireVersionOutput" -ForegroundColor Green
            $aspireInstalled = $true
        }
    } else {
        throw "Aspire CLI not found"
    }
} catch {
    Write-Host "  Aspire CLI 13+ not found" -ForegroundColor Yellow
    $missingPrereqs += @{
        Name = "Aspire CLI (version 13+)"
        InstallMethod = "script"
        ManualUrl = "https://aspire.dev"
    }
}

# Check for local .NET SDK installation in quickstart/aspire folder
Write-Host "Checking for local .NET SDK..." -ForegroundColor Gray
# Use absolute path if repo exists, otherwise construct the expected path
if (Test-Path $repoPath) {
    $localDotnetPath = Join-Path (Resolve-Path $repoPath).Path "privatemarketplace\quickstart\aspire\.dotnet"
} else {
    $localDotnetPath = Join-Path (Join-Path $PWD $repoPath) "privatemarketplace\quickstart\aspire\.dotnet"
}
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

# Check for repository
Write-Host "Checking for repository..." -ForegroundColor Gray
if (Test-Path $repoPath) {
    # Verify it's the correct repository by checking for the quickstart folder
    $quickstartPath = Join-Path $repoPath "privatemarketplace/quickstart"
    if (Test-Path $quickstartPath) {
        Write-Host "  Repository found at: $repoPath" -ForegroundColor Green
        $repoExists = $true
    } else {
        Write-Host "  Repository folder exists but appears incomplete" -ForegroundColor Yellow
        $missingPrereqs += @{
            Name = "VS Marketplace Repository"
            InstallMethod = "download"
            DownloadMethod = "ZIP download"
            TargetFolder = $repoPath
            ManualUrl = $repoUrl
        }
    }
} else {
    Write-Host "  Repository not found" -ForegroundColor Yellow
    $missingPrereqs += @{
        Name = "VS Marketplace Repository"
        InstallMethod = "download"
        DownloadMethod = "ZIP download"
        TargetFolder = $repoPath
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
        } elseif ($prereq.InstallMethod -eq "script") {
            Write-Host "  - $($prereq.Name): via installation script" -ForegroundColor Green
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
    
    # Download repository first if missing (needed for local .NET SDK installation)
    if (-not $repoExists) {
        Write-Host "`nDownloading VS Marketplace Repository..." -ForegroundColor Cyan
        
        # Download as ZIP
        Write-Host "  Downloading repository as ZIP (branch: $repoBranch)..." -ForegroundColor Gray
        $zipUrl = "$repoUrl/archive/refs/heads/$repoBranch.zip"
        $tempZipPath = Join-Path $env:TEMP "vsmarketplace-$repoBranch.zip"
        
        try {
            Invoke-WebRequest -Uri $zipUrl -OutFile $tempZipPath -UseBasicParsing
            Write-Host "  ZIP downloaded successfully." -ForegroundColor Green
            
            Write-Host "  Extracting ZIP file..." -ForegroundColor Gray
            $tempExtractPath = Join-Path $env:TEMP "vsmarketplace-extract"
            if (Test-Path $tempExtractPath) {
                Remove-Item -Path $tempExtractPath -Recurse -Force
            }
            Expand-Archive -Path $tempZipPath -DestinationPath $tempExtractPath -Force
            
            # Move the extracted folder to the target location
            $extractedFolder = Join-Path $tempExtractPath "vsmarketplace-$repoBranch"
            if (Test-Path $extractedFolder) {
                Move-Item -Path $extractedFolder -Destination $repoPath -Force
            }
            
            # Clean up temporary files
            Remove-Item -Path $tempZipPath -Force
            Remove-Item -Path $tempExtractPath -Recurse -Force
            Write-Host "  Extraction complete." -ForegroundColor Green
            $repoExists = $true
            
            # Now that repo exists, recalculate the absolute path for local .NET SDK
            $localDotnetPath = Join-Path (Resolve-Path $repoPath).Path "privatemarketplace\quickstart\aspire\.dotnet"
        }
        catch {
            Write-Host "  Error downloading or extracting ZIP: $_" -ForegroundColor Red
            Write-Host "  Please download the repository manually from: $repoUrl" -ForegroundColor Yellow
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
    
    # Install Aspire CLI if missing
    if (-not $aspireInstalled) {
        Write-Host "`nInstalling Aspire CLI..." -ForegroundColor Cyan
        
        try {
            # Download and run the installation script
            Write-Host "  Downloading installation script..." -ForegroundColor Gray
            $installScript = Invoke-WebRequest -Uri "https://aspire.dev/install.ps1" -UseBasicParsing
            
            if ($installScript.StatusCode -eq 200) {
                Write-Host "  Executing installation script..." -ForegroundColor Gray
                # Execute the script
                Invoke-Expression $installScript.Content
                
                # Refresh environment variables to pick up the new PATH
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                
                Write-Host "  Aspire CLI installation completed." -ForegroundColor Green
            } else {
                throw "Failed to download installation script"
            }
        } catch {
            Write-Host "  Error installing Aspire CLI: $_" -ForegroundColor Red
            Write-Host "  Please install manually by running: Invoke-WebRequest -Uri 'https://aspire.dev/install.ps1' -UseBasicParsing | Invoke-Expression" -ForegroundColor Yellow
            return
        }
        
        # Verify aspire command is available
        try {
            $aspireVersion = aspire --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Aspire CLI is now available: $aspireVersion" -ForegroundColor Green
                
                # Enable automatic .NET SDK installation now that Aspire is installed
                Write-Host "  Enabling automatic .NET SDK installation feature..." -ForegroundColor Gray
                aspire config set features.dotnetSdkInstallationEnabled true
                Write-Host "  Automatic .NET SDK installation enabled." -ForegroundColor Green
            } else {
                Write-Host "  Aspire CLI still not available. You may need to restart your terminal." -ForegroundColor Yellow
                Write-Host "  Please run the script again." -ForegroundColor Yellow
                return
            }
        } catch {
            Write-Host "  Aspire CLI still not available. You may need to restart your terminal." -ForegroundColor Yellow
            Write-Host "  Please run the script again." -ForegroundColor Yellow
            return
        }
    }
    
    Write-Host "`nAll prerequisites installed successfully." -ForegroundColor Green
} else {
    Write-Host "`nAll prerequisites satisfied." -ForegroundColor Green
}

# Navigate to the quickstart folder
Write-Host "`nNavigating to privatemarketplace/quickstart..." -ForegroundColor Cyan
$quickstartPath = Join-Path $repoPath "privatemarketplace/quickstart"

if (-not (Test-Path $quickstartPath)) {
    Write-Host "Error: privatemarketplace/quickstart folder not found!" -ForegroundColor Red
    return
}

Set-Location $quickstartPath
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

# Run aspire
Write-Host "`nRunning aspire..." -ForegroundColor Cyan
try {
    aspire run --non-interactive
}
catch {
    Write-Host "Error running aspire: $_" -ForegroundColor Red
    return
}
