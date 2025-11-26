# PowerShell script to download and run the VS Marketplace repository

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
$repoPath = Join-Path $env:TEMP "vsmarketplace-quickstart"
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

# Check Aspire CLI (local .NET tool)
Write-Host "Checking for Aspire CLI..." -ForegroundColor Gray

# If repo doesn't exist, Aspire can't exist either (depends on local .NET)
if (-not (Test-Path $repoPath)) {
    Write-Host "  Aspire CLI not found (repository not present)" -ForegroundColor Yellow
    $missingPrereqs += @{
        Name = "Aspire CLI (version 13+)"
        InstallMethod = "dotnet-tool"
        ManualUrl = "https://learn.microsoft.com/dotnet/aspire"
    }
} else {
    # Check if .NET tool manifest exists and Aspire is installed
    $toolManifestPath = Join-Path $repoPath "privatemarketplace/quickstart/aspire/.config/dotnet-tools.json"
    $aspireToolInstalled = $false
    
    if (Test-Path $toolManifestPath) {
        try {
            $manifest = Get-Content $toolManifestPath -Raw | ConvertFrom-Json
            if ($manifest.tools."aspire") {
                $aspireToolInstalled = $true
                Write-Host "  Aspire CLI found in tool manifest" -ForegroundColor Green
                $aspireInstalled = $true
            }
        } catch {
            Write-Host "  Error reading tool manifest" -ForegroundColor Yellow
        }
    }
    
    if (-not $aspireToolInstalled) {
        Write-Host "  Aspire CLI not found as local .NET tool" -ForegroundColor Yellow
        $missingPrereqs += @{
            Name = "Aspire CLI (version 13+)"
            InstallMethod = "dotnet-tool"
            ManualUrl = "https://learn.microsoft.com/dotnet/aspire"
        }
    }
}

# Check for local .NET SDK installation in quickstart/aspire folder
Write-Host "Checking for local .NET SDK..." -ForegroundColor Gray

# If repo doesn't exist, .NET SDK can't exist either
if (-not (Test-Path $repoPath)) {
    Write-Host "  Local .NET SDK not found (repository not present)" -ForegroundColor Yellow
    $localDotnetPath = Join-Path (Join-Path $PWD $repoPath) "privatemarketplace\quickstart\aspire\.dotnet"
    $missingPrereqs += @{
        Name = ".NET SDK $dotnetVersion (local)"
        InstallMethod = "dotnet-install"
        Version = $dotnetVersion
        InstallPath = $localDotnetPath
        ManualUrl = "https://dotnet.microsoft.com/download/dotnet/10.0"
    }
} else {
    # Repo exists, check for .NET SDK
    $localDotnetPath = Join-Path (Resolve-Path $repoPath).Path "privatemarketplace\quickstart\aspire\.dotnet"
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
        } elseif ($prereq.InstallMethod -eq "dotnet-tool") {
            Write-Host "  - $($prereq.Name): via dotnet tool install" -ForegroundColor Green
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
    
    # Download quickstart/aspire folder if missing (needed for local .NET SDK installation)
    if (-not $repoExists) {
        Write-Host "`nDownloading quickstart files..." -ForegroundColor Cyan
        
        # Download only the privatemarketplace/quickstart folder
        Write-Host "  Downloading from repository (branch: $repoBranch)..." -ForegroundColor Gray
        $zipUrl = "$repoUrl/archive/refs/heads/$repoBranch.zip"
        $tempZipPath = Join-Path $env:TEMP "vsmarketplace-$repoBranch.zip"
        
        try {
            Invoke-WebRequest -Uri $zipUrl -OutFile $tempZipPath -UseBasicParsing
            Write-Host "  ZIP downloaded successfully." -ForegroundColor Green
            
            Write-Host "  Extracting quickstart folder..." -ForegroundColor Gray
            $tempExtractPath = Join-Path $env:TEMP "vsmarketplace-extract"
            if (Test-Path $tempExtractPath) {
                Remove-Item -Path $tempExtractPath -Recurse -Force
            }
            Expand-Archive -Path $tempZipPath -DestinationPath $tempExtractPath -Force
            
            # Copy only the privatemarketplace/quickstart folder to the target location
            $extractedQuickstartFolder = Join-Path $tempExtractPath "vsmarketplace-$repoBranch\privatemarketplace\quickstart"
            if (Test-Path $extractedQuickstartFolder) {
                # Create the target structure
                $targetQuickstartPath = Join-Path $repoPath "privatemarketplace\quickstart"
                New-Item -ItemType Directory -Path $targetQuickstartPath -Force | Out-Null
                
                # Copy the quickstart contents
                Copy-Item -Path "$extractedQuickstartFolder\*" -Destination $targetQuickstartPath -Recurse -Force
                Write-Host "  Quickstart files copied successfully." -ForegroundColor Green
            } else {
                throw "Quickstart folder not found in downloaded archive"
            }
            
            # Clean up temporary files
            Remove-Item -Path $tempZipPath -Force
            Remove-Item -Path $tempExtractPath -Recurse -Force
            Write-Host "  Download complete." -ForegroundColor Green
            $repoExists = $true
            
            # Now that quickstart exists, recalculate the absolute path for local .NET SDK
            $localDotnetPath = Join-Path (Resolve-Path $repoPath).Path "privatemarketplace\quickstart\aspire\.dotnet"
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
    
    # Install Aspire CLI as local .NET tool if missing
    if (-not $aspireInstalled) {
        Write-Host "`nInstalling Aspire CLI as local .NET tool..." -ForegroundColor Cyan
        
        try {
            $aspirePath = Join-Path $repoPath "privatemarketplace/quickstart/aspire"
            
            # Use the local .NET SDK to install Aspire
            $localDotnetExe = Join-Path $localDotnetPath "dotnet.exe"
            
            # Create tool manifest if it doesn't exist
            Write-Host "  Creating .NET tool manifest..." -ForegroundColor Gray
            Push-Location $aspirePath
            try {
                & $localDotnetExe new tool-manifest --force 2>$null | Out-Null
                
                # Install Aspire as a local tool
                Write-Host "  Installing Aspire CLI..." -ForegroundColor Gray
                & $localDotnetExe tool install aspire --prerelease
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  Aspire CLI installed successfully as local .NET tool." -ForegroundColor Green
                    $aspireInstalled = $true
                } else {
                    throw "Failed to install Aspire CLI"
                }
            } finally {
                Pop-Location
            }
        } catch {
            Write-Host "  Error installing Aspire CLI: $_" -ForegroundColor Red
            Write-Host "  Please install manually with: dotnet tool install aspire --prerelease" -ForegroundColor Yellow
            return
        }
    }
    
    Write-Host "`nAll prerequisites installed successfully." -ForegroundColor Green
} else {
    Write-Host "`nAll prerequisites satisfied." -ForegroundColor Green
}

# Save the original directory
$originalDirectory = Get-Location

# Navigate to the quickstart folder
Write-Host "`nNavigating to privatemarketplace/quickstart/aspire..." -ForegroundColor Cyan
$quickstartPath = Join-Path $repoPath "privatemarketplace/quickstart/aspire"

if (-not (Test-Path $quickstartPath)) {
    Write-Host "Error: privatemarketplace/quickstart/aspire folder not found!" -ForegroundColor Red
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

# Run aspire using local .NET tool
Write-Host "`nRunning aspire..." -ForegroundColor Cyan
try {
    # Use dotnet tool run to execute the local Aspire installation
    & $localDotnetExe tool run aspire run --non-interactive
}
catch {
    Write-Host "Error running aspire: $_" -ForegroundColor Red
}
finally {
    # Return to original directory
    Set-Location $originalDirectory
}
