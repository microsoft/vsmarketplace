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
$wingetAvailable = $false

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
    $aspireVersion = aspire --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Aspire CLI detected: $aspireVersion" -ForegroundColor Green
        $aspireInstalled = $true
    } else {
        throw "Aspire CLI not found"
    }
} catch {
    Write-Host "  Aspire CLI not found" -ForegroundColor Yellow
    $missingPrereqs += @{
        Name = "Aspire CLI"
        InstallMethod = "script"
        ManualUrl = "https://aspire.dev"
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
            Write-Host "    URL: $($prereq.ManualUrl)" -ForegroundColor Gray
        } elseif ($prereq.InstallMethod -eq "winget") {
            Write-Host "  - $($prereq.Name): via winget" -ForegroundColor Green
        } elseif ($prereq.InstallMethod -eq "script") {
            Write-Host "  - $($prereq.Name): via installation script" -ForegroundColor Green
        }
    }
    
    # Prompt for confirmation
    Write-Host ""
    $response = Read-Host "Do you want to proceed with installation? (y/n)"
    if ($response -ne 'y') {
        Write-Host "Installation cancelled by user." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "`n=== Installing Prerequisites ===" -ForegroundColor Cyan
    
    # Install Docker if missing
    if (-not $dockerInstalled) {
        Write-Host "`nInstalling Docker Desktop..." -ForegroundColor Cyan
        
        if ($wingetAvailable) {
            Write-Host "  Using winget to install Docker Desktop..." -ForegroundColor Gray
            winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Docker Desktop installed successfully." -ForegroundColor Green
                Write-Host "  IMPORTANT: Please start Docker Desktop and wait for it to be ready, then re-run this script." -ForegroundColor Yellow
                exit 0
            } else {
                Write-Host "  Failed to install Docker Desktop via winget." -ForegroundColor Red
                Write-Host "  Please install Docker Desktop manually from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
                exit 1
            }
        } else {
            Write-Host "  winget not available. Please install Docker Desktop manually from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
            exit 1
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
            exit 1
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
                Write-Host "  Please close this terminal and run the script again." -ForegroundColor Yellow
                exit 1
            }
        } catch {
            Write-Host "  Aspire CLI still not available. You may need to restart your terminal." -ForegroundColor Yellow
            Write-Host "  Please close this terminal and run the script again." -ForegroundColor Yellow
            exit 1
        }
    }
    
    Write-Host "`nAll prerequisites installed successfully." -ForegroundColor Green
} else {
    Write-Host "`nAll prerequisites satisfied." -ForegroundColor Green
}

# Define repository details
$repoUrl = "https://github.com/microsoft/vsmarketplace"
$repoPath = $Path

# Check if repository already exists
if (Test-Path $repoPath) {
    Write-Host "Repository already exists at: $repoPath" -ForegroundColor Yellow
    $response = Read-Host "Do you want to delete and re-download? (y/n)"
    if ($response -eq 'y') {
        Write-Host "Removing existing repository..." -ForegroundColor Yellow
        Remove-Item -Path $repoPath -Recurse -Force
    } else {
        Write-Host "Using existing repository..." -ForegroundColor Green
        Set-Location $repoPath
        Set-Location "privatemarketplace/quickstart"
        Write-Host "Running aspire..." -ForegroundColor Cyan
        aspire run
        exit
    }
}

# Check if git is available
$useGit = $false
try {
    $gitVersion = git --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        $useGit = $true
        Write-Host "Git detected: $gitVersion" -ForegroundColor Gray
    }
}
catch {
    Write-Host "Git not found in PATH." -ForegroundColor Yellow
}

if ($useGit) {
    # Clone using git
    Write-Host "Cloning repository using git..." -ForegroundColor Cyan
    
    try {
        git clone $repoUrl $repoPath
        Write-Host "Repository cloned successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Error cloning repository: $_" -ForegroundColor Red
        Write-Host "Falling back to ZIP download..." -ForegroundColor Yellow
        $useGit = $false
    }
}

if (-not $useGit) {
    # Download as ZIP (fallback)
    Write-Host "Downloading repository as ZIP..." -ForegroundColor Cyan
    $zipUrl = "$repoUrl/archive/refs/heads/main.zip"
    $tempZipPath = Join-Path $env:TEMP "vsmarketplace-main.zip"
    
    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $tempZipPath -UseBasicParsing
        Write-Host "ZIP downloaded successfully." -ForegroundColor Green
        
        Write-Host "Extracting ZIP file..." -ForegroundColor Cyan
        $tempExtractPath = Join-Path $env:TEMP "vsmarketplace-extract"
        if (Test-Path $tempExtractPath) {
            Remove-Item -Path $tempExtractPath -Recurse -Force
        }
        Expand-Archive -Path $tempZipPath -DestinationPath $tempExtractPath -Force
        
        # Move the extracted folder to the target location
        $extractedFolder = Join-Path $tempExtractPath "vsmarketplace-main"
        if (Test-Path $extractedFolder) {
            Move-Item -Path $extractedFolder -Destination $repoPath -Force
        }
        
        # Clean up temporary files
        Remove-Item -Path $tempZipPath -Force
        Remove-Item -Path $tempExtractPath -Recurse -Force
        Write-Host "Extraction complete." -ForegroundColor Green
    }
    catch {
        Write-Host "Error downloading or extracting ZIP: $_" -ForegroundColor Red
        exit 1
    }
}

# Navigate to the quickstart folder
Write-Host "`nNavigating to privatemarketplace/quickstart..." -ForegroundColor Cyan
$quickstartPath = Join-Path $repoPath "privatemarketplace/quickstart"

if (-not (Test-Path $quickstartPath)) {
    Write-Host "Error: privatemarketplace/quickstart folder not found!" -ForegroundColor Red
    exit 1
}

Set-Location $quickstartPath
Write-Host "Current directory: $(Get-Location)" -ForegroundColor Gray

# Run aspire
Write-Host "`nRunning aspire..." -ForegroundColor Cyan
try {
    aspire run --non-interactive
}
catch {
    Write-Host "Error running aspire: $_" -ForegroundColor Red
    exit 1
}
