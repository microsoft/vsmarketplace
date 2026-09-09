<#
.SYNOPSIS
    Sets up and runs a Private Marketplace quickstart environment for Visual Studio.

.DESCRIPTION
    This script automates the installation and configuration of all prerequisites needed to run
    a local Private Marketplace for Visual Studio, including Docker, the .NET SDK, and the
    Aspire CLI. By default those tools are installed locally in a temporary folder to avoid
    interfering with system-wide installations; see -UseGlobalInstalls to reuse existing ones.

    Visual Studio itself is never installed by this script. An existing installation of
    Visual Studio 18.11 or later is required, and the script verifies it before continuing.

.PARAMETER UseGlobalInstalls
    When specified, existing machine-wide installations of the .NET SDK and the Aspire CLI are
    reused instead of installing portable copies, provided they meet the minimum versions
    (.NET SDK 10.0.100+, Aspire CLI 13.0.0+). Anything missing or too old is still installed
    locally, so the modes mix.

.PARAMETER RepoUrl
    Repository to download the quickstart files from.
    Defaults to https://github.com/microsoft/vsmarketplace. Use this to test from a fork.

.PARAMETER RepoBranch
    Branch to download the quickstart files from. Defaults to 'main'.
    Use this to test preview changes that have not merged yet. Branch names containing
    '/' are supported. When a branch other than 'main' is used, the quickstart installs
    into a branch-specific folder so it cannot pick up stale files from a previous run.

.PARAMETER SkipVSVersionCheck
    Proceeds even when the Visual Studio version cannot be verified or is below the minimum.
    Useful when the Visual Studio Installer (which provides vswhere.exe) is unavailable.

.EXAMPLE
    .\Run-PrivateMarketplace.ps1
    Runs the full quickstart setup, checking and installing prerequisites as needed.

.EXAMPLE
    .\Run-PrivateMarketplace.ps1 -UseGlobalInstalls
    Reuses machine-wide .NET SDK and Aspire CLI installations when they are new enough.

.EXAMPLE
    .\Run-PrivateMarketplace.ps1 -RepoBranch 'dev/mcumming/privatemarketplace-preview-docs'
    Runs the quickstart using files from the specified branch instead of 'main'.

.NOTES
    Requires: PowerShell 5.1 or later, Internet connection for downloads
    Requires: Visual Studio 18.11 or later, already installed
    Exit Codes:
        0 - Success
        1 - Error occurred (see error messages)
#>
[CmdletBinding()]
param(
    [Parameter(HelpMessage="Reuse machine-wide .NET SDK and Aspire CLI installations when they meet the minimum versions")]
    [switch]$UseGlobalInstalls,
    
    [Parameter(HelpMessage="Repository to download quickstart files from")]
    [string]$RepoUrl = "https://github.com/microsoft/vsmarketplace",
    
    [Parameter(HelpMessage="Branch to download quickstart files from (use to test unmerged preview changes)")]
    [string]$RepoBranch = "main",
    
    [Parameter(HelpMessage="Proceed even if the Visual Studio version cannot be verified")]
    [switch]$SkipVSVersionCheck
)

$ErrorActionPreference = "Stop"

#region Configuration
# Accept clone-style URLs (trailing '/' or '.git') without breaking the archive URL.
$RepoUrl = ($RepoUrl.TrimEnd('/')) -replace '\.git$', ''

# GitHub replaces '/' with '-' when naming archive files and their root folder,
# and '/' is not valid in a local path, so slugify the branch for anything on disk.
$branchSlug = $RepoBranch -replace '[^A-Za-z0-9._-]', '-'

# Repository name, used to locate the root folder inside the downloaded archive.
$repoName = ($RepoUrl -split '/')[-1]

# Path to this quickstart inside the repository. Used to locate the files in the downloaded
# archive and to point at the right folder when something goes wrong.
$quickstartRepoPath = "privatemarketplace/preview/quickstart/vs"

# Keep the documented folder for the default branch, but sandbox other branches so a
# previous run's files are never mistaken for the branch under test.
$rootFolderName = if ($RepoBranch -eq 'main') {
    "privatemarketplace-quickstart-vs"
} else {
    "privatemarketplace-quickstart-vs-$branchSlug"
}

# Script configuration - modify these values to customize the behavior
$Config = @{
    # Repository settings (overridable via -RepoUrl / -RepoBranch)
    RepoUrl = $RepoUrl
    RepoBranch = $RepoBranch
    RepoName = $repoName
    BranchSlug = $branchSlug
    QuickstartRepoPath = $quickstartRepoPath
    
    # Version requirements
    DotNetVersion = "10.0.100"  # Minimum .NET SDK version. The latest patch in this major.minor channel is installed.
    AspireVersion = "13.0.0"    # Minimum Aspire CLI version accepted from a machine-wide installation.
    MinimumVSVersion = "18.11"  # Minimum Visual Studio version required for VS extension support.
    
    # Installation paths
    RootPath = Join-Path $env:TEMP $rootFolderName
    
    # Timeout settings
    MaxDockerWaitTime = 120  # Maximum seconds to wait for Docker to start (first-time can take 90+ seconds)
    DockerCheckInterval = 2   # Seconds between Docker readiness checks
}

# Derived paths (calculated from configuration)
$Paths = @{
    Root = $Config.RootPath
    LocalAspire = Join-Path $Config.RootPath ".aspire"
    # The Aspire CLI is installed under <LocalAspire>\bin. For script-route installs the CLI
    # treats the parent of its own bin directory as ASPIRE_HOME, so this keeps ASPIRE_HOME on
    # .aspire instead of the quickstart root, where it would collide with the project's own
    # aspire.config.json and write cache, cli, and logs folders next to the AppHost.
    LocalAspireBin = Join-Path $Config.RootPath ".aspire\bin"
    LocalDotnet = Join-Path $Config.RootPath ".dotnet"
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
        
        # A condition that throws counts as "not ready yet". Probes often shell out to
        # tools that fail while a service is still starting, and under
        # $ErrorActionPreference = 'Stop' that would otherwise terminate the script.
        $conditionMet = $false
        try {
            $conditionMet = [bool](& $Condition)
        } catch {
            $conditionMet = $false
        }

        if ($conditionMet) {
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

function Get-PowerShellExecutable {
    if (Test-CommandExists "pwsh") {
        return "pwsh.exe"
    }
    return "powershell.exe"
}

<#
.SYNOPSIS
    Converts a tool version string into a comparable [version].
.DESCRIPTION
    Strips semantic-versioning prerelease labels and build metadata so values such as
    "13.6.0-preview.1.26418.4+95ba0548" compare as 13.6.0. Returns $null when the input
    does not contain at least a major and minor number.
#>
function ConvertTo-ComparableVersion {
    param([string]$RawVersion)

    if ([string]::IsNullOrWhiteSpace($RawVersion)) { return $null }

    # Keep only the numeric core: drop anything from the first '-' or '+'
    $core = ($RawVersion.Trim() -split '[-+]')[0]
    $parts = @($core -split '\.' | Where-Object { $_ -match '^\d+$' })

    if ($parts.Count -lt 2) { return $null }
    if ($parts.Count -gt 4) { $parts = $parts[0..3] }

    try { return [version]($parts -join '.') } catch { return $null }
}

<#
.SYNOPSIS
    Runs a native command and captures stdout without letting stderr become a PowerShell error.
.DESCRIPTION
    Native tools often write progress or warnings to stderr. Under
    $ErrorActionPreference = 'Stop', Windows PowerShell 5.1 turns that output into a
    terminating NativeCommandError. Redirecting both streams through ProcessStartInfo avoids
    creating an error record at all.
.OUTPUTS
    An object with ExitCode and StandardOutput, or $null when the process could not start.
#>
function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$false)]
        [string]$Arguments = ""
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    try {
        [void]$process.Start()
    } catch [System.ComponentModel.Win32Exception] {
        return $null
    } catch [System.InvalidOperationException] {
        return $null
    }

    $standardOutput = $process.StandardOutput.ReadToEnd()
    [void]$process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return [pscustomobject]@{
        ExitCode       = $process.ExitCode
        StandardOutput = $standardOutput
    }
}

<#
.SYNOPSIS
    Determines whether the Docker engine is running and accepting requests.
.DESCRIPTION
    Gates on the exit code rather than matching error text, so it is not affected by the
    display language or by harmless warnings such as the blkio message Docker emits on
    some hosts.
#>
function Test-DockerEngineReady {
    $dockerCommand = Get-Command docker.exe -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $dockerCommand -or -not (Test-Path $dockerCommand.Source)) {
        return $false
    }

    $result = Invoke-NativeCommand -FilePath $dockerCommand.Source -Arguments "info"
    if ($null -eq $result) {
        return $false
    }

    return ($result.ExitCode -eq 0 -and $result.StandardOutput -match 'Server:')
}

<#
.SYNOPSIS
    Returns the version of an Aspire CLI executable, or $null when it cannot be determined.
#>
function Get-AspireCliVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) { return $null }

    $result = Invoke-NativeCommand -FilePath $Path -Arguments "--version"
    if ($null -eq $result -or $result.ExitCode -ne 0) {
        return $null
    }

    $firstLine = ($result.StandardOutput -split "`r?`n" | Select-Object -First 1)
    return ConvertTo-ComparableVersion $firstLine
}

<#
.SYNOPSIS
    Returns the highest released .NET SDK version that meets a minimum, or $null.
.DESCRIPTION
    Accepts the output of "dotnet --list-sdks". Any SDK at or above the minimum qualifies,
    regardless of its major.minor channel, so a newer SDK is never reported as missing.
    Prerelease SDKs are ignored so the quickstart runs on a released toolchain.
#>
function Get-SdkVersionMeetingMinimum {
    param(
        [string[]]$SdkLines,
        [string]$MinimumVersion
    )

    $minimum = ConvertTo-ComparableVersion $MinimumVersion
    if (-not $minimum) { return $null }

    $best = $null
    foreach ($line in $SdkLines) {
        # Lines look like: 10.0.400 [C:\Program Files\dotnet\sdk]
        if ($line -notmatch '^(\S+)\s+\[') { continue }
        $rawVersion = $matches[1]

        if ($rawVersion -match '-') { continue }

        $version = ConvertTo-ComparableVersion $rawVersion
        if ($version -and $version -ge $minimum) {
            if (-not $best -or $version -gt $best) { $best = $version }
        }
    }

    return $best
}

<#
.SYNOPSIS
    Finds a machine-wide .NET SDK that meets the minimum version.
.OUTPUTS
    An object with Version and Root (the DOTNET_ROOT directory), or $null.
#>
function Get-GlobalDotNetInfo {
    param([string]$MinimumVersion)

    $command = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $command) { return $null }

    try { $sdkLines = & $command.Source --list-sdks 2>$null } catch { return $null }

    $version = Get-SdkVersionMeetingMinimum -SdkLines $sdkLines -MinimumVersion $MinimumVersion
    if (-not $version) { return $null }

    return [pscustomobject]@{
        Version = $version
        Root    = Split-Path -Parent $command.Source
    }
}

<#
.SYNOPSIS
    Finds a machine-wide Aspire CLI that meets the minimum version.
.OUTPUTS
    An object with Version and Path (the aspire executable), or $null.
#>
function Get-GlobalAspireInfo {
    param([string]$MinimumVersion)

    $command = Get-Command aspire -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $command) { return $null }

    $version = Get-AspireCliVersion -Path $command.Source
    $minimum = ConvertTo-ComparableVersion $MinimumVersion
    if ($version -and $minimum -and $version -ge $minimum) {
        return [pscustomobject]@{
            Version = $version
            Path    = $command.Source
        }
    }

    return $null
}

<#
.SYNOPSIS
    Locates vswhere.exe.
.DESCRIPTION
    vswhere ships with the Visual Studio Installer rather than with Visual Studio itself, so
    it is normally under Program Files (x86) even for 64-bit installs. It can be absent if the
    Installer was removed or damaged, so the caller must handle $null.
#>
function Find-VSWhere {
    $candidates = @()
    if (${env:ProgramFiles(x86)}) {
        $candidates += Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    }
    if ($env:ProgramFiles) {
        $candidates += Join-Path $env:ProgramFiles "Microsoft Visual Studio\Installer\vswhere.exe"
    }
    
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    
    $onPath = Get-Command vswhere.exe -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    
    return $null
}

function Get-VSInstancesFromState {
    $instancesRoot = Join-Path $env:ProgramData "Microsoft\VisualStudio\Packages\_Instances"
    if (-not (Test-Path $instancesRoot)) {
        return $null
    }
    
    $results = @()
    foreach ($dir in (Get-ChildItem $instancesRoot -Directory -ErrorAction SilentlyContinue)) {
        $stateFile = Join-Path $dir.FullName "state.json"
        if (-not (Test-Path $stateFile)) { continue }
        
        try {
            $state = Get-Content $stateFile -Raw -ErrorAction Stop | ConvertFrom-Json
        } catch {
            Write-Verbose "Could not parse $stateFile : $_"
            continue
        }
        
        $installPath = $state.installationPath
        if (-not $installPath) { continue }
        
        # Only the IDE can host extensions. Build Tools launches a command prompt, not devenv.
        $hasIde = Test-Path (Join-Path $installPath "Common7\IDE\devenv.exe")
        if (-not $hasIde) { continue }
        
        $versionText = $state.catalogInfo.buildVersion
        if (-not $versionText) { $versionText = $state.installationVersion }
        if (-not $versionText) { continue }
        
        $results += [pscustomobject]@{
            installationVersion = $versionText
            installationPath    = $installPath
            displayName         = if ($state.installationName) { $state.installationName } else { "Visual Studio" }
        }
    }
    
    return ,$results
}

function Get-VisualStudioInstallation {
    $instances = $null
    $method = $null
    
    $vsWherePath = Find-VSWhere
    if ($vsWherePath) {
        try {
            # -prerelease so preview channels count; JSON avoids fragile text parsing.
            $output = & $vsWherePath -products * -prerelease -format json 2>$null | Out-String
            if ($LASTEXITCODE -eq 0) {
                $method = "vswhere"
                $instances = if ([string]::IsNullOrWhiteSpace($output)) { @() } else { @($output | ConvertFrom-Json) }
            } else {
                Write-Verbose "vswhere exited with code $LASTEXITCODE"
            }
        } catch {
            Write-Verbose "vswhere query failed: $_"
        }
    } else {
        Write-Verbose "vswhere.exe not found; falling back to installer instance state."
    }
    
    if ($null -eq $instances) {
        $instances = Get-VSInstancesFromState
        if ($null -ne $instances) {
            $method = "installer state"
        }
    }
    
    if ($null -eq $instances) {
        # Neither vswhere nor the instance store could be read.
        return @{ Status = 'Unknown'; Method = 'none' }
    }
    
    $best = $null
    foreach ($instance in @($instances)) {
        # Build Tools has no IDE, so it cannot host extensions.
        if ($instance.productId -eq 'Microsoft.VisualStudio.Product.BuildTools') {
            continue
        }
        
        $parsedVersion = $null
        if (-not [version]::TryParse($instance.installationVersion, [ref]$parsedVersion)) {
            Write-Verbose "Could not parse VS version: $($instance.installationVersion)"
            continue
        }
        
        if ($null -eq $best -or $parsedVersion -gt $best.Version) {
            $best = @{
                Status = 'Found'
                Version = $parsedVersion
                DisplayName = $instance.displayName
                Path = $instance.installationPath
                Method = $method
            }
        }
    }
    
    if ($null -eq $best) {
        return @{ Status = 'NotFound'; Method = $method }
    }
    
    return $best
}

#endregion Helper Functions

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)



Write-StatusMessage "Private Marketplace for Visual Studio Quickstart" -Level Info

# Check and install prerequisites
Write-StatusMessage "`nChecking prerequisites..." -Level Info

# Initialize tracking variables
$missingPrereqs = @()
$blockingPrereqs = @()  # Prerequisites this script cannot install on the user's behalf
$dockerInstalled = $false
$aspireInstalled = $false
$dotnetInstalled = $false
$repoExists = $false
$wingetAvailable = $false

# Use configured values and paths
$repoUrl = $Config.RepoUrl
$repoBranch = $Config.RepoBranch
$rootPath = $Paths.Root
$dotnetVersion = $Config.DotNetVersion
$minimumVSVersion = [version]$Config.MinimumVSVersion
$localAspirePath = $Paths.LocalAspire
$localAspireBinPath = $Paths.LocalAspireBin
$localDotnetPath = $Paths.LocalDotnet

# Effective tool locations. These default to the portable copies in the quickstart folder and
# are redirected to machine-wide installations when -UseGlobalInstalls finds suitable versions.
$effectiveDotnetRoot = $localDotnetPath
$effectiveAspireExe  = Join-Path $localAspireBinPath "aspire.exe"
$usingGlobalDotnet   = $false
$usingGlobalAspire   = $false

if ($UseGlobalInstalls) {
    Write-Host "`nLooking for machine-wide installations (-UseGlobalInstalls)..." -ForegroundColor Cyan


    $globalDotnet = Get-GlobalDotNetInfo -MinimumVersion $Config.DotNetVersion
    if ($globalDotnet) {
        Write-Host "  .NET SDK $($globalDotnet.Version) found at: $($globalDotnet.Root)" -ForegroundColor Green
        $effectiveDotnetRoot = $globalDotnet.Root
        $usingGlobalDotnet = $true
    } else {
        Write-Host "  No machine-wide .NET SDK $($Config.DotNetVersion)+ found; a local SDK will be used" -ForegroundColor Yellow
    }

    $globalAspire = Get-GlobalAspireInfo -MinimumVersion $Config.AspireVersion
    if ($globalAspire) {
        Write-Host "  Aspire CLI $($globalAspire.Version) found at: $($globalAspire.Path)" -ForegroundColor Green
        $effectiveAspireExe = $globalAspire.Path
        $usingGlobalAspire = $true
    } else {
        Write-Host "  No machine-wide Aspire CLI $($Config.AspireVersion)+ found; a portable copy will be used" -ForegroundColor Yellow
    }
}

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
}



# Check Visual Studio. This script never installs Visual Studio; it only verifies that a new
# enough installation is already present.
Write-Host "Checking for Visual Studio $minimumVSVersion or later..." -ForegroundColor Gray
$vsInstall = Get-VisualStudioInstallation

if ($SkipVSVersionCheck) {
    Write-Host "  Skipping the Visual Studio version check (-SkipVSVersionCheck)." -ForegroundColor Yellow
    if ($vsInstall.Status -eq 'Found') {
        Write-Host "  Detected: $($vsInstall.DisplayName) ($($vsInstall.Version))" -ForegroundColor Gray
    }
} elseif ($vsInstall.Status -eq 'Found' -and $vsInstall.Version -ge $minimumVSVersion) {
    Write-Host "  Visual Studio detected: $($vsInstall.DisplayName) ($($vsInstall.Version))" -ForegroundColor Green
    Write-Host "    $($vsInstall.Path)" -ForegroundColor Gray
} elseif ($vsInstall.Status -eq 'Found') {
    Write-Host "  Visual Studio $($vsInstall.Version) found, but $minimumVSVersion or later is required" -ForegroundColor Yellow
    Write-Host "    $($vsInstall.DisplayName)" -ForegroundColor Gray
    Write-Host "    $($vsInstall.Path)" -ForegroundColor Gray
    $blockingPrereqs += New-PrerequisiteInfo -Name "Visual Studio $minimumVSVersion or later" `
        -InstallMethod "manual" -ManualUrl "https://visualstudio.microsoft.com/downloads/" `
        -Version "$($vsInstall.Version) installed" -InstallPath $vsInstall.Path
} elseif ($vsInstall.Status -eq 'NotFound') {
    Write-Host "  Visual Studio not found" -ForegroundColor Yellow
    $blockingPrereqs += New-PrerequisiteInfo -Name "Visual Studio $minimumVSVersion or later" `
        -InstallMethod "manual" -ManualUrl "https://visualstudio.microsoft.com/downloads/" `
        -Version "not installed"
} else {
    # Detection itself failed. Visual Studio may well be installed and new enough, so warn
    # and continue rather than blocking on something we could not actually determine.
    Write-Host "  Could not determine the Visual Studio version." -ForegroundColor Yellow
    Write-Host "    vswhere.exe was not found and the Visual Studio Installer's instance" -ForegroundColor Gray
    Write-Host "    data could not be read. This does not necessarily mean Visual Studio" -ForegroundColor Gray
    Write-Host "    is missing; the Visual Studio Installer may have been removed." -ForegroundColor Gray
    Write-Host "    Ensure Visual Studio $minimumVSVersion or later is installed before using" -ForegroundColor Gray
    Write-Host "    Visual Studio extensions from the Private Marketplace." -ForegroundColor Gray
}

# Check Aspire CLI (local installation)
# Note: this intentionally ignores any machine-wide Aspire CLI unless -UseGlobalInstalls is
# specified. The quickstart keeps its tools in the temporary folder so it does not interfere
# with system-wide installs.
Write-Host "Checking for local Aspire CLI..." -ForegroundColor Gray

# If root doesn't exist, Aspire can't exist either
$aspirePrereq = New-PrerequisiteInfo -Name "Aspire CLI ($($Config.AspireVersion)+) (local)" -InstallMethod "aspire-local" `
    -InstallPath $localAspireBinPath -ManualUrl "https://learn.microsoft.com/dotnet/aspire"

if ($usingGlobalAspire) {
    Write-Host "  Skipped, using the machine-wide installation" -ForegroundColor Green
    $aspireInstalled = $true
} elseif (-not (Test-Path $rootPath)) {
    Write-Host "  Local Aspire CLI not found (quickstart folder not present)" -ForegroundColor Yellow
    $missingPrereqs += $aspirePrereq
} else {
    $aspireExePath = Join-Path $localAspireBinPath "aspire.exe"
    if (Test-Path $aspireExePath) {
        # Verify the version rather than trusting that the file exists, so a stale copy from
        # an earlier run is replaced instead of being used.
        $localAspireVersion = Get-AspireCliVersion -Path $aspireExePath
        $minimumAspireVersion = ConvertTo-ComparableVersion $Config.AspireVersion

        if ($localAspireVersion -and $minimumAspireVersion -and $localAspireVersion -ge $minimumAspireVersion) {
            Write-Host "  Local Aspire CLI $localAspireVersion found at: $localAspireBinPath" -ForegroundColor Green
            $aspireInstalled = $true
        } elseif ($localAspireVersion) {
            Write-Host "  Local Aspire CLI $localAspireVersion is below the minimum $($Config.AspireVersion)" -ForegroundColor Yellow
            $missingPrereqs += $aspirePrereq
        } else {
            Write-Host "  Local Aspire CLI found but its version could not be determined" -ForegroundColor Yellow
            $missingPrereqs += $aspirePrereq
        }
    } else {
        Write-Host "  Local Aspire CLI not found" -ForegroundColor Yellow
        $missingPrereqs += $aspirePrereq
    }
}

# Check for local .NET SDK installation
Write-Host "Checking for local .NET SDK..." -ForegroundColor Gray

# Extract major.minor version for channel checking
$versionParts = $dotnetVersion -split '\.'
if ($versionParts.Count -ge 2) {
    $channel = "$($versionParts[0]).$($versionParts[1])"
} else {
    $channel = $dotnetVersion
}

# If root doesn't exist, .NET SDK can't exist either
$dotnetPrereq = New-PrerequisiteInfo -Name ".NET SDK $dotnetVersion+ (local)" -InstallMethod "dotnet-install" `
    -Version $dotnetVersion -InstallPath $localDotnetPath -ManualUrl "https://dotnet.microsoft.com/download/dotnet/10.0"

if ($usingGlobalDotnet) {
    Write-Host "  Skipped, using the machine-wide installation" -ForegroundColor Green
    $dotnetInstalled = $true
} elseif (-not (Test-Path $rootPath)) {
    Write-Host "  Local .NET SDK not found (quickstart folder not present)" -ForegroundColor Yellow
    $missingPrereqs += $dotnetPrereq
} else {
    $localDotnetExePath = Join-Path $localDotnetPath "dotnet.exe"

    if (Test-Path $localDotnetExePath) {
        # Check the actual installed SDK versions
        try {
            $installedSdks = & $localDotnetExePath --list-sdks 2>$null
            # Any SDK at or above the minimum qualifies, including newer channels
            $usableSdk = Get-SdkVersionMeetingMinimum -SdkLines $installedSdks -MinimumVersion $dotnetVersion

            if ($usableSdk) {
                Write-Host "  Local .NET SDK $usableSdk found at: $localDotnetPath" -ForegroundColor Green
                $dotnetInstalled = $true
            } else {
                Write-Host "  No local .NET SDK $dotnetVersion or later found. Installed: $($installedSdks -join ', ')" -ForegroundColor Yellow
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

# Stop on prerequisites this script cannot install. Visual Studio in particular is never
# installed here, so the user has to resolve it before the quickstart can continue.
if ($blockingPrereqs.Count -gt 0) {
    Write-Host "`n=== Action Required ===" -ForegroundColor Red
    Write-Host "The following prerequisites must be installed manually before continuing:" -ForegroundColor Yellow
    foreach ($prereq in $blockingPrereqs) {
        Write-Host "  - $($prereq.Name)" -ForegroundColor Yellow
        if ($prereq.Version) {
            Write-Host "    Current: $($prereq.Version)" -ForegroundColor Gray
        }
        if ($prereq.InstallPath) {
            Write-Host "    Location: $($prereq.InstallPath)" -ForegroundColor Gray
        }
        if ($prereq.ManualUrl) {
            Write-Host "    Download: $($prereq.ManualUrl)" -ForegroundColor Gray
        }
    }
    Write-Host "`nUpdate or install Visual Studio using the Visual Studio Installer, then run this" -ForegroundColor Gray
    Write-Host "script again." -ForegroundColor Gray
    exit 1
}

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
        } elseif ($prereq.InstallMethod -eq "aspire-local") {
            Write-Host "  - $($prereq.Name): via local portableinstallation" -ForegroundColor Green
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
    
    # Download quicklaunch files if missing
    if (-not $repoExists) {
        Write-Host "`nDownloading quicklaunch files..." -ForegroundColor Cyan
        
        New-DirectoryIfNeeded -Path $rootPath
        
        # Download only this quickstart's folder out of the repository archive
        Write-Host "  Downloading from repository (branch: $repoBranch)..." -ForegroundColor Gray
        $zipUrl = "$repoUrl/archive/refs/heads/$repoBranch.zip"
        $tempZipPath = Join-Path $env:TEMP "vsmarketplace-preview-$branchSlug.zip"
        
        # A wrong branch name is the most likely failure here, and the raw archive error does
        # not say so. Probe first and fail with something actionable.
        try {
            $null = Invoke-WebRequest -Uri $zipUrl -Method Head -UseBasicParsing -ErrorAction Stop
        } catch {
            $statusCode = $null
            if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
            
            if ($statusCode -eq 404) {
                Write-Host "  Branch '$repoBranch' was not found in $repoUrl" -ForegroundColor Red
                Write-Host "`n  Check the branch name:" -ForegroundColor Yellow
                Write-Host "    - Branch names are case-sensitive and must match exactly." -ForegroundColor Gray
                Write-Host "    - Use the branch name, not a local folder or worktree name;" -ForegroundColor Gray
                Write-Host "      these often differ (for example 'dev/user/my-branch' vs 'dev-user-my-branch')." -ForegroundColor Gray
                Write-Host "    - The branch must be pushed to $repoUrl before it can be downloaded." -ForegroundColor Gray
                Write-Host "`n  Branches: $repoUrl/branches" -ForegroundColor Gray
                Write-Host "  To use the default branch instead, re-run without -RepoBranch." -ForegroundColor Gray
                exit 1
            }
            
            # Anything else (offline, proxy, transient) still gets the normal download attempt,
            # which reports the underlying error.
            Write-Verbose "Branch probe did not succeed (status: $statusCode); continuing to download."
        }
        
        try {
            $downloadSuccess = Invoke-WithProgress -Activity "Downloading Quickstart Files" -Status "Downloading from repository..." -ScriptBlock {
                Get-FileWithVerification -Url $zipUrl -OutFile $tempZipPath
            }
            if (-not $downloadSuccess) {
                throw "Failed to download repository archive"
            }
            Write-Host "  ZIP downloaded successfully." -ForegroundColor Green
            
            # Extract files
            $tempExtractPath = Join-Path $env:TEMP "vsmarketplace-preview-extract-$branchSlug"
            if (Test-Path $tempExtractPath) {
                Remove-Item -Path $tempExtractPath -Recurse -Force
            }
            Write-Progress -Activity "Extracting Quickstart Files" -Status "Extracting files..."
            Expand-Archive -Path $tempZipPath -DestinationPath $tempExtractPath -Force
            Write-Progress -Activity "Extracting Quickstart Files" -Completed
            
            # Copy quicklaunch folder contents directly to root (excluding local tool folders)
            $extractedquicklaunchFolder = Join-Path $tempExtractPath "$repoName-$branchSlug\$($quickstartRepoPath -replace '/','\')"
            if (Test-Path $extractedquicklaunchFolder) {
                # Get all items in quicklaunch folder except hidden tool folders
                Get-ChildItem -Path $extractedquicklaunchFolder | Where-Object { 
                    $_.Name -notin @('.dotnet')
                } | ForEach-Object {
                    Copy-Item -Path $_.FullName -Destination $rootPath -Recurse -Force
                }
                Write-Host "  quicklaunch files copied successfully." -ForegroundColor Green
            } else {
                throw "'$quickstartRepoPath' not found in downloaded archive for branch '$repoBranch'"
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
            Write-Host "  Please download manually from: $repoUrl/tree/$repoBranch/$quickstartRepoPath" -ForegroundColor Yellow
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
        Write-Host "`nInstalling the latest .NET SDK for channel $channel locally (minimum $dotnetVersion)..." -ForegroundColor Cyan
        
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
            
            # Extract major.minor version from dotnetVersion (e.g., "10.0" from "10.0.100")
            $versionParts = $dotnetVersion -split '\.'
            if ($versionParts.Count -ge 2) {
                $channel = "$($versionParts[0]).$($versionParts[1])"
            } else {
                throw "Invalid .NET version format: $dotnetVersion"
            }
            
            Write-Host "  Querying latest patch version for channel $channel..." -ForegroundColor Gray
            
            # Run the installation script with -Channel to get the latest patch version
            # This installs the latest patch version for the specified major.minor channel
            Invoke-WithProgress -Activity "Installing .NET SDK" -Status "Installing latest .NET SDK for channel $channel..." -ScriptBlock {
                & $dotnetInstallScript -Channel $channel -InstallDir $localDotnetPath -NoPath
            }
            
            # Verify installation by checking for dotnet.exe and running --list-sdks
            $localDotnetExeCheck = Join-Path $localDotnetPath "dotnet.exe"
            if (Test-Path $localDotnetExeCheck) {
                try {
                    $installedSdks = & $localDotnetExeCheck --list-sdks 2>$null
                    # Find any SDK matching the major.minor version pattern
                    $majorMinorPattern = "^$([regex]::Escape($channel))\.(\d+)\s"
                    $matchingSdk = $installedSdks | Where-Object { $_ -match $majorMinorPattern }
                    
                    if ($matchingSdk) {
                        # Extract the actual version number that was installed
                        if ($matchingSdk -match "^([\d\.]+)\s") {
                            $installedVersion = $matches[1]
                            Write-Host "  .NET SDK $installedVersion installed successfully (latest patch for channel $channel)." -ForegroundColor Green
                        } else {
                            Write-Host "  .NET SDK installed successfully (channel $channel)." -ForegroundColor Green
                        }
                        $dotnetInstalled = $true
                    } else {
                        throw "SDK for channel $channel not found after installation"
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
            exit 1
        }
    }
    
    
    # Install Aspire CLI locally if missing
    if (-not $aspireInstalled) {
        Write-Host "`nInstalling Aspire CLI locally..." -ForegroundColor Cyan
        
        try {
            New-DirectoryIfNeeded -Path $localAspireBinPath
            
            # Download the Aspire installation script.
            # Note: write the response straight to disk. aspire.dev serves the script as
            # application/octet-stream, so Invoke-WebRequest returns Content as a byte[];
            # piping that to Out-File would write one decimal byte value per line and
            # produce a corrupt script.
            $tempScriptPath = Join-Path $env:TEMP "aspire-install.ps1"
            $downloadSuccess = Invoke-WithProgress -Activity "Installing Aspire CLI" -Status "Downloading Aspire installation script..." -ScriptBlock {
                Get-FileWithVerification -Url "https://aspire.dev/install.ps1" -OutFile $tempScriptPath
            }
            if (-not $downloadSuccess) {
                throw "Failed to download Aspire installation script"
            }

            # Execute the installation script with -InstallPath parameter.
            # -SkipPath keeps the portable install out of the user's PATH.
            # Installing into <.aspire>\bin keeps ASPIRE_HOME on the .aspire folder rather
            # than the quickstart root; see the LocalAspireBin note in the configuration.
            # The CLI archive is a large download, so a dropped connection is retried rather
            # than failing the whole quickstart and discarding everything installed so far.
            $aspireExePath = Join-Path $localAspireBinPath "aspire.exe"
            $maxAttempts = 3
            for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
                try {
                    Invoke-WithProgress -Activity "Installing Aspire CLI" -Status "Installing Aspire CLI to: $localAspireBinPath" -ScriptBlock {
                        & $tempScriptPath -InstallPath $localAspireBinPath -SkipPath
                    }
                } catch {
                    Write-Verbose "Aspire CLI install attempt $attempt failed: $_"
                }
                
                if (Test-Path $aspireExePath) { break }
                
                if ($attempt -lt $maxAttempts) {
                    Write-Host "  Download did not complete. Retrying ($attempt of $($maxAttempts - 1))..." -ForegroundColor Yellow
                    Start-Sleep -Seconds (5 * $attempt)
                }
            }

            # Clean up temp script
            Remove-Item $tempScriptPath -Force -ErrorAction SilentlyContinue

            # Verify aspire.exe exists
            if (Test-Path $aspireExePath) {
                Write-Host "  Aspire CLI installed successfully." -ForegroundColor Green
                $aspireInstalled = $true

                # Remove Aspire paths from USER PATH environment variable
                Write-Host "  Removing Aspire from system PATH..." -ForegroundColor Gray
                Remove-PathFromEnvironment -PathPatterns @($localAspireBinPath, $localAspirePath)
            } else {
                throw "aspire.exe not found after installation"
            }
        } catch {
            Write-Host "  Error installing Aspire CLI: $_" -ForegroundColor Red
            Write-Host "  Please install manually from: https://aspire.dev" -ForegroundColor Yellow
            exit 1
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
    
} else {
    Write-Host "`nAll prerequisites satisfied." -ForegroundColor Green
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

# Set up the .NET SDK environment
$dotnetScope = if ($usingGlobalDotnet) { "machine-wide" } else { "local" }
Write-Host "`nConfiguring $dotnetScope .NET SDK environment..." -ForegroundColor Cyan
$effectiveDotnetExe = Join-Path $effectiveDotnetRoot "dotnet.exe"

if (Test-Path $effectiveDotnetExe) {
    # Point the toolchain at the selected SDK
    $env:DOTNET_ROOT = $effectiveDotnetRoot
    $env:DOTNET_MULTILEVEL_LOOKUP = "0"  # Prevent looking in global locations
    $env:PATH = "$effectiveDotnetRoot;$env:PATH"
    
    Write-Host "  DOTNET_ROOT set to: $effectiveDotnetRoot" -ForegroundColor Gray
    Write-Host "  .NET version: " -NoNewline -ForegroundColor Gray
    & $effectiveDotnetExe --version
    
    # Verify an SDK that meets the minimum is available. Any version at or above the
    # minimum qualifies, so a newer SDK is never reported as missing.
    $availableSdks = & $effectiveDotnetExe --list-sdks 2>$null
    $readySdk = Get-SdkVersionMeetingMinimum -SdkLines $availableSdks -MinimumVersion $dotnetVersion
    if ($readySdk) {
        Write-Host "  .NET SDK $readySdk is ready." -ForegroundColor Green
    } else {
        Write-Host "  Warning: No .NET SDK $dotnetVersion or later found at $effectiveDotnetRoot." -ForegroundColor Yellow
    }
} else {
    Write-Host "  Error: .NET SDK executable not found at: $effectiveDotnetExe" -ForegroundColor Red
    exit 1
}

# Ensure Docker is running
Write-Host "`nChecking Docker engine status..." -ForegroundColor Cyan
$dockerEngineRunning = Test-DockerEngineReady
if ($dockerEngineRunning) {
    Write-Host "  Docker engine is running." -ForegroundColor Green
} else {
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
            Test-DockerEngineReady
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

# Run quickstart using the selected Aspire CLI
Write-Host "`nRunning quickstart..." -ForegroundColor Cyan
try {
    # Use the Aspire executable selected during prerequisite checks
    $aspireExePath = $effectiveAspireExe
    
    # Verify environment is still configured
    Write-Host "  Using .NET SDK: $($env:DOTNET_ROOT)" -ForegroundColor Gray
    Write-Host "  .NET version: " -NoNewline -ForegroundColor Gray
    & $effectiveDotnetExe --version
    
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
    
    # Launch Aspire with explicit environment variables so it uses the selected .NET SDK
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $aspireExePath
    $psi.Arguments = "run --non-interactive"
    $psi.UseShellExecute = $false
    $psi.WorkingDirectory = $rootPath
    $psi.EnvironmentVariables["DOTNET_ROOT"] = $effectiveDotnetRoot
    $psi.EnvironmentVariables["DOTNET_MULTILEVEL_LOOKUP"] = "0"
    $psi.EnvironmentVariables["PATH"] = "$effectiveDotnetRoot;$($env:PATH)"

    
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
    Write-Host "IMPORTANT: Disconnect Visual Studio from the Private Marketplace" -ForegroundColor Yellow
    Write-Host "===========================================" -ForegroundColor Yellow
    Write-Host "To restore normal Visual Studio Marketplace access:" -ForegroundColor Gray
    Write-Host "  1. In Visual Studio, select Tools > Options" -ForegroundColor Gray
    Write-Host "  2. Search for 'private', then select Environment > Extensions" -ForegroundColor Gray
    Write-Host "  3. Clear the 'Use private marketplace' checkbox" -ForegroundColor Gray
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
        
    } else {
        Write-Host "`nTemporary folder preserved at: $rootPath" -ForegroundColor Green
        Write-Host "`nTo run the Private Marketplace again:" -ForegroundColor Cyan
        Write-Host "  1. Open PowerShell" -ForegroundColor Gray
        Write-Host "  2. Run: & '$rootPath\Run-PrivateMarketplace.ps1'" -ForegroundColor Gray
        Write-Host ""
    }
}
