<#
Copyright (c) Microsoft Corporation. All rights reserved.
#>

<#
.SYNOPSIS
Publishes a VSIX file to an Azure Artifacts feed.

.DESCRIPTION
This script uploads a specified VSIX file to a given Azure Artifacts feed.

.PARAMETER VsixFilePath
The file path of the VSIX package to be published. This parameter is mandatory.

.PARAMETER DestinationFeed
The destination Azure Artifacts feed where the VSIX package will be published. This parameter is mandatory.

.EXAMPLE
Publish-VsixToAzureArtifacts.ps1 -VsixFilePath "C:\path\to\extension.vsix" -DestinationFeed "https://pkgs.dev.azure.com/<organization>/_packaging/<feed>/npm/registry/"

This example publishes the VSIX file located at "C:\path\to\extension.vsix" to the specified Azure Artifacts feed.

.NOTES
Ensure that you have the necessary permissions, Packaging (Read & Write), to publish to the specified Azure Artifacts feed.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$VsixFilePath,

    [Parameter(Mandatory = $true)]
    [string]$DestinationFeed
)

$ProgressPreference = "SilentlyContinue";

############################################################################################################
## Functions
############################################################################################################

<#
.SYNOPSIS
 Checks for the latest version of the vsts-npm-auth module from the npm registry.
 If the module is not installed locally, it installs the latest version.
 If the module is installed but outdated, it updates to the latest version.
#>
function Invoke-VstsNpmAuthModuleCheck {

    # Get the latest available version of the vsts-npm-auth module from the registry
    Write-Host "Checking for latest vsts-npm-auth module version on registry https://registry.npmjs.com..." -ForegroundColor Gray;
    $latestAvailableAuthModuleVersionString = & npm show vsts-npm-auth version --registry https://registry.npmjs.com | Out-String;
    $latestAvailableAuthModuleVersion = [System.Version]::Parse($latestAvailableAuthModuleVersionString);
    Write-Host "Latest available vsts-npm-auth module version is $latestAvailableAuthModuleVersion" -ForegroundColor Gray;

    # Check if the vsts-npm-auth module is available locally
    Write-Host "Checking for locally available vsts-npm-auth module..." -ForegroundColor Gray;
    $authModule = & npm list -g --depth=0 | Select-String 'vsts-npm-auth';

    if ($null -eq $authModule) {
        Write-Host "vsts-npm-auth not found. Installing latest version from registry https://registry.npmjs.com..." -ForegroundColor Yellow;

        & npm install -g vsts-npm-auth --registry https://registry.npmjs.com --always-auth false | Write-Host;
    }
    else {
        $authModuleVersionString = $authModule -replace '`-- vsts-npm-auth@', '' | Out-String;
        $authModuleVersionString = $authModuleVersionString -replace '[^\d\.]', '';
        $authModuleVersion = [System.Version]::Parse($authModuleVersionString);
        Write-Host "Detected vsts-npm-auth module $authModuleVersion locally" -ForegroundColor Gray;

        if ($authModuleVersion -lt $latestAvailableAuthModuleVersion) {
            Write-Host "Updating vsts-npm-auth module to $latestAvailableAuthModuleVersion" -ForegroundColor Yellow;
            & npm update -g vsts-npm-auth --registry https://registry.npmjs.com --always-auth false | Write-Host;
        }
    }
}

<#
.SYNOPSIS
 Sets up authentication for npm to publish packages to a specified Azure Artifacts feed.
.DESCRIPTION
 This function creates a .npmrc file in the specified output directory and configures it to use the provided Azure Artifacts feed.
 It also checks for the availability of the vsts-npm-auth module and installs it if necessary.
.PARAMETER DestinationFeed
 The URL of the Azure Artifacts npm feed to publish packages to.
.PARAMETER OutputDir
 The directory where the .npmrc file will be created. Defaults to the script's directory.
.PARAMETER Force
 If set to true, the function will force the installation of the vsts-npm-auth module even if it is already installed.
.EXAMPLE
 Set-NpmAuthentication -DestinationFeed "https://pkgs.dev.azure.com/your-org/_packaging/your-feed/npm/registry/"
 This example sets up authentication for npm to publish packages to the specified Azure Artifacts npm feed.
#>
function Set-NpmAuthentication {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DestinationFeed,
        [Parameter(Mandatory = $false)]
        [string]$OutputDir = $PSScriptRoot,
        [Parameter(Mandatory = $false)]
        [bool]$Force = $false
    )

    $currentDir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path);

    if ($OutputDir -like "$currentDir*") {
        # If the output directory is a subdirectory of the current directory,
        # Then create the .npmrc file in the current directory (and authenticate only once)
        $npmrcPath = [System.IO.Path]::Combine($currentDir, ".npmrc");
    }
    else {
        # If the output directory is not a subdirectory of the current directory,
        # Then create the .npmrc file in the output directory
        $npmrcPath = [System.IO.Path]::Combine($OutputDir, ".npmrc");
    }

    # Check if the .npmrc file already exists and skip re-authentication if not forced
    if ((Test-Path $npmrcPath) -and (-not $Force)) {
        Write-Host "Reusing existing .npmrc file at $npmrcPath" -ForegroundColor Green;
    }
    else {
        Write-Host "Creating new .npmrc file at $npmrcPath" -ForegroundColor Yellow;
        
        # Create or overwrite the .npmrc file
        @"
registry=$DestinationFeed
always-auth=true
"@ | Out-File -FilePath $npmrcPath -Encoding utf8;

        # Check if vsts-npm-auth is available locally
        Invoke-VstsNpmAuthModuleCheck;
    }

    # Authenticate using vsts-npm-auth
    & vsts-npm-auth -C $npmrcPath -T $npmrcPath -N | Write-Verbose;
}

<#
.SYNOPSIS
 Publishes an npm package to the specified Azure Artifacts feed.
.DESCRIPTION
 This function publishes an npm package to the specified Azure Artifacts feed using npm.
 It also sets the appropriate tag for the package based on the provided version and target platform.
.PARAMETER NpmPackageId
 The ID of the npm package to be published.
.PARAMETER NpmPackageVersion
 The version of the npm package to be published.
.PARAMETER Version
 The version of the package to publish.
.PARAMETER TargetPlatform
 The target platform for the package. If specified, a tag will be added to the package.
.PARAMETER DestinationFeed
 The URL of the Azure Artifacts npm feed to publish the package to.
.PARAMETER OutputDir
 The directory where the .npmrc file will be created. Defaults to the script's directory.
.PARAMETER ForceAuthentication
 If set to true, the function will force the installation of the vsts-npm-auth module even if it is already installed.
.EXAMPLE
 Publish-Npm -NpmPackageId "MyPackage" -NpmPackageVersion "1.0.0" -Version "1.0.0" -TargetPlatform "win32-x64" -DestinationFeed "https://pkgs.dev.azure.com/your-org/_packaging/your-feed/npm/registry/"
 This example publishes the specified npm package to the Azure Artifacts feed with the specified parameters.
#>
function Publish-Npm {
    param (
        [string]$NpmPackageId,
        [string]$NpmPackageVersion,
        [string]$Version,
        [string]$TargetPlatform,
        [string]$DestinationFeed,
        [string]$OutputDir
    )

    $localNpmrcPath = [System.IO.Path]::Combine((Get-Location).Path, ".npmrc");
    $npmrcPath = [System.IO.Path]::Combine((Get-Item $OutputDir).Parent.FullName, ".npmrc");

    if (Test-Path $npmrcPath) {
        # Reuse OutpuDir .npmrc file if it exists.
        # This function assumes authentication already happens if the file exists, to avoid re-authentication.
        Copy-Item -Path $npmrcPath -Destination $localNpmrcPath -Force;  
        Write-Host "Copied .npmrc file to the local folder: $localNpmrcPath" -ForegroundColor Green;  
    }
    else {
        # Create a new .npmrc file in the current directory
        Write-Host "Creating new .npmrc file in the current directory" -ForegroundColor Yellow;
        
        # Create or overwrite the .npmrc file
        @"
registry=$DestinationFeed
always-auth=true
"@ | Out-File -FilePath .npmrc -Encoding utf8;
    }    

    if ($TargetPlatform) {
        Write-Host "Publishing NPM package $NpmPackageId@$NpmPackageVersion ($TargetPlatform)" -ForegroundColor White
    }
    else {
        Write-Host "Publishing NPM package $NpmPackageId@$NpmPackageVersion (universal)" -ForegroundColor White
    }

    # Publish the package
    $publishOutput = Invoke-NpmPublish -DestinationFeed $DestinationFeed -TargetPlatform $TargetPlatform -Version $Version;

    $ExpectedNpmPackageInfo = "$NpmPackageId@$NpmPackageVersion";
    if ($publishOutput -match "\+ $ExpectedNpmPackageInfo") {
        Write-Host "Publish completed" -ForegroundColor Green;
    }
    elseif ($publishOutput -match "401 Unauthorized") {
        Write-Error "Publish failed: 401 Unauthorized";

        Set-NpmAuthentication -OutputDir $OutputDir -DestinationFeed $DestinationFeed -Force | Write-Verbose;

        Invoke-NpmPublish -DestinationFeed $DestinationFeed -TargetPlatform $TargetPlatform -Version $Version | Write-Verbose;
    }
    else {
        Write-Error "Publish failed";
    }

    # Delete the .npmrc file
    if (Test-Path .npmrc) {
        Remove-Item -Path .npmrc -Force | Write-Verbose;
    }
}

<#
 .SYNOPSIS
 Publishes a package to the specified Azure Artifacts npm feed.
.DESCRIPTION
 This function publishes a package to the specified Azure Artifacts npm feed using npm.
 It also sets the appropriate tag for the package based on the provided version and target platform.
.PARAMETER DestinationFeed
 The URL of the Azure Artifacts npm feed to publish the package to.
.PARAMETER Version
 The version of the package to publish.
.PARAMETER TargetPlatform
 The target platform for the package. If specified, a tag will be added to the package.
.EXAMPLE
 Invoke-NpmPublish -DestinationFeed "https://pkgs.dev.azure.com/your-org/_packaging/your-feed/npm/registry/" -Version "1.0.0" -TargetPlatform "win32-x64"
 This example publishes a package to the specified Azure Artifacts npm feed with the version "1.0.0" and the target platform "win32-x64".
#>
function Invoke-NpmPublish {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DestinationFeed,
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $false)]
        [string]$TargetPlatform
    )

    # Publish the package
    $publishArgs = @("--registry $DestinationFeed", "--ignore-scripts");

    if ($TargetPlatform) {
        # NPM publishing rules dictate that you must specify a tag using --tag when publishing a prerelease version.
        # NPM tags do not support SemVer-like tags. To avoid this, we replace '.' with '_'
        # https://docs.npmjs.com/cli/v9/commands/npm-publish#tag
        # As tags always move to the latest version having the same tag (which causes the previous version to have the tag removed),
        # we use a different tag for each version.
        $TagVersion = $Version -replace '\.', '_';
        $Tag = "$TagVersion-TP.$TargetPlatform";

        $publishArgs += "--tag", "$Tag";
    }

    Write-Verbose "Publishing with args: $publishArgs";

    $publishOutput = & npm publish @publishArgs | Out-String;

    Write-Verbose $publishOutput;

    return $publishOutput;
}

<#
.SYNOPSIS
 Constructs the file path for a VSIX file based on the provided parameters.
.DESCRIPTION
 This function constructs the file path for a VSIX file based on the provided parameters.
 It uses the publisher name, extension name, version, and target platform to create the file path.
.PARAMETER OutputDir
 The directory where the VSIX file will be saved.
.PARAMETER PublisherName
 The name of the publisher of the VSIX file.
.PARAMETER ExtensionName
 The name of the extension.
.PARAMETER Version
 The version of the extension.
.PARAMETER TargetPlatform
 The target platform for the extension (optional).
.EXAMPLE
 Get-VsixFilePath -OutputDir "C:\VSIX" -PublisherName "MyPublisher" -ExtensionName "MyExtension" -Version "1.0.0" -TargetPlatform "win32-x64"
 This example constructs the file path for a VSIX file with the specified parameters.
#>
function Get-VsixFilePath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$OutputDir,
        [Parameter(Mandatory = $true)]
        [string]$PublisherName,
        [Parameter(Mandatory = $true)]
        [string]$ExtensionName,
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $false)]
        [string]$TargetPlatform
    )

    # Construct the VSIX file path
    $vsixFilePath = [System.IO.Path]::Combine($OutputDir, $PublisherName, "$($PublisherName).$($ExtensionName).$($Version)");
    if ($TargetPlatform) {
        $vsixFilePath += "-$($TargetPlatform)";
    }
    $vsixFilePath += ".vsix";

    return $vsixFilePath;
}

<#
.SYNOPSIS
 Extracts a VSIX file to the specified output directory.
.DESCRIPTION
 This function extracts a VSIX file to the specified output directory.
.PARAMETER VsixFilePath
 The path to the VSIX file to be extracted.
.PARAMETER OutputDir
 The directory where the VSIX file will be extracted.
.EXAMPLE
 Invoke-VsixExtraction -VsixFilePath "C:\VSIX\MyExtension.vsix" -OutputDir "C:\VSIX\Extracted"
 This example extracts the VSIX file to the specified output directory.
#>
function Invoke-VsixExtraction {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VsixFilePath,
        [Parameter(Mandatory = $true)]
        [string]$OutputDir
    )

    # Check if the VSIX file exists
    if (-not (Test-Path $VsixFilePath)) {
        Write-Error "VSIX file not found: $VsixFilePath";
        return;
    }

    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Write-Verbose;
    }

    Write-Verbose "Extracting VSIX $VsixFilePath to $OutputDir";

    $zipArchive = [System.IO.Compression.ZipFile]::OpenRead($VsixFilePath);

    foreach ($entry in $zipArchive.Entries) {
        $entryFullPath = [System.IO.Path]::Combine($OutputDir, $entry.FullName);
        $entryDir = [System.IO.Path]::GetDirectoryName($entryFullPath);
        if (-not (Test-Path $entryDir)) {
            New-Item -ItemType Directory -Path $entryDir -Force | Write-Verbose;
        }
        if ($entry.FullName.EndsWith("/")) {
            New-Item -ItemType Directory -Path $entryFullPath -Force | Write-Verbose;
        }
        else {
            $entryStream = $entry.Open();
            $fileStream = [System.IO.FileStream]::new($entryFullPath, [System.IO.FileMode]::Create);
            Write-Verbose "Extracting $($entry.FullName) to $entryFullPath";
            $entryStream.CopyTo($fileStream);
            $fileStream.Flush();
            $fileStream.Close();
            $entryStream.Close();
        }
    }

    $zipArchive.Dispose();

    Write-Host "Extracted VSIX: to $OutputDir" -ForegroundColor Green;
}

<#
.SYNOPSIS
 Constructs the npm package identifier based on the provided parameters.
.DESCRIPTION
 This function constructs the npm package identifier based on the provided parameters.
.PARAMETER PublisherName
 The name of the publisher of the npm package.
.PARAMETER ExtensionName
 The name of the extension.
.PARAMETER ExtensionVersion
 The version of the extension.
.PARAMETER TargetPlatform
 The target platform for the extension (optional).
.EXAMPLE
 Get-NpmPackageIdentifier -PublisherName "MyPublisher" -ExtensionName "MyExtension" -ExtensionVersion "1.0.0" -TargetPlatform "win32-x64"
 This example constructs the npm package identifier with the specified parameters.
 This example returns "MyPublisher.MyExtension@1.0.0-TP.win32-x64".
#>
function Get-NpmPackageIdentifier {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PublisherName,
        [Parameter(Mandatory = $true)]
        [string]$ExtensionName,
        [Parameter(Mandatory = $true)]
        [string]$ExtensionVersion,
        [Parameter(Mandatory = $false)]
        [string]$TargetPlatform
    )

    $npmIdentifier = "$PublisherName.$ExtensionName@$ExtensionVersion";

    if ($TargetPlatform) {
        $npmIdentifier += "-TP.$TargetPlatform";
    }

    return $npmIdentifier;
}

<#
.SYNOPSIS
 Copies an asset to the npm root directory.
.DESCRIPTION
 This function copies an asset to the npm root directory if it exists in the specified source directory.
.PARAMETER AssetPaths
 The paths of the assets to be copied.
.PARAMETER SourceDirectory
 The source directory where the assets are located.
.PARAMETER TargetDirectory
 The target directory where the assets will be copied.
.EXAMPLE
 Copy-AssetToNpmRoot -AssetPaths @("asset1", "asset2") -SourceDirectory "C:\Source" -TargetDirectory "C:\Target"
 This example copies the specified assets from the source directory to the target directory.
#>
function Copy-AssetToNpmRoot {
    param (
        [string[]]$AssetPaths,
        [string]$SourceDirectory,
        [string]$TargetDirectory
    )

    $detectedAssetPath = $AssetPaths
    | ForEach-Object { [System.IO.Path]::Combine($TargetDirectory, $_) }
    | Where-Object { Test-Path $_ }
    | Select-Object -First 1;

    if ($detectedAssetPath) {
        Write-Verbose "Detected asset: $detectedAssetPath";
        Write-Verbose "Copying asset $detectedAssetPath to $TargetDirectory";
        Copy-Item -Path $detectedAssetPath -Destination $TargetDirectory -Force | Write-Verbose
        Write-Verbose "Copied asset $detectedAssetPath to $TargetDirectory";
    }
}

############################################################################################################
## Variables
############################################################################################################

$VerboseArgument = @{}
if ($PSBoundParameters.ContainsKey('Verbose')) {
    $VerboseArgument['Verbose'] = $PSBoundParameters['Verbose'];
}
else {
    $VerboseArgument['Verbose'] = $false;
}
Write-Verbose "Verbose mode: $($VerboseArgument['Verbose'] -eq $true)";

$currentDir = (Get-Location).Path;
$OutputDir = [System.IO.Path]::Combine($currentDir, "output");
$npmBinDir = [System.IO.Path]::Combine($OutputDir, "bin");

# Variables related to the extracted VSIX
$extractedExtensionDir = [System.IO.Path]::Combine($OutputDir, "extracted");
$extractedExtensionManifestDir = [System.IO.Path]::Combine($extractedExtensionDir, "extension");
$vsCodeManifestFilePath = [System.IO.Path]::Combine($extractedExtensionManifestDir, "package.json");
$vsixManifestFilePath = [System.IO.Path]::Combine($extractedExtensionDir, "extension.vsixmanifest");

# Variables related to the npm publish request
$payloadFilePath = [System.IO.Path]::Combine($OutputDir, "package.json");
$validReadmeFileNames = @("readme.txt", "readme.md", "readme.markdown", "README");
$validChangelogFileNames = @("changelog.txt", "changelog.md", "changelog.markdown", "CHANGELOG");
$validLicenseFileNames = @("license.txt", "license.md", "license.markdown", "LICENSE");

# Separator used to separate the original VSIX version and target platform in the npm package version.
# This is compliant with SemVer v2.0.0 (https://semver.org/#spec-item-9) which states that a
# pre-release tag may consist of a series of dot-separated identifiers, which must comprise alphanumeric or
# hyphen characters. The identifiers must not be empty and must not include symbols, whitespace, or special
# characters.
# This will also shield us against any confusion resulting from any prerelease tags already present in the
# VSIX version.
# E.g.: 1.0.0-TP.alphine-arm64, 1.0.0-alpha-TP.alphine-x64
$NpmVersionTargetPlatformSeparator = "-TP.";

############################################################################################################
## Validate the arguments
############################################################################################################

# A file path to a local VSIX was provided.
# Verify the file exists or bail out.
if (-not (Test-Path $VsixFilePath)) {
    Write-Error "The provided VSIX file path does not exist: $VsixFilePath";
    exit 1;
}

if ($VsixFilePath -notlike "*.vsix") {
    Write-Error "The provided file is not a VSIX file: $VsixFilePath";
    exit 1;
}

############################################################################################################
## Clean up the current directory
############################################################################################################

if (Test-Path $OutputDir) {
    Write-Verbose "Removing output directory: $OutputDir" ;
    Remove-Item -Path $OutputDir -Recurse @VerboseArgument | Write-Verbose;
    Write-Verbose "Removed output directory: $OutputDir" ;
}

# Create the output directory, with optional verbose output
Write-Verbose "Creating output directory: $OutputDir";
New-Item -ItemType Directory -Path $OutputDir -Force @VerboseArgument | Write-Verbose;
Write-Verbose "Created output directory: $OutputDir";

############################################################################################################
## Copy the VSIX file to the output directory to embed it into the npm package
############################################################################################################

Write-Verbose "Using local VSIX file: $VsixFilePath";

$vsixFileName = [System.IO.Path]::GetFileName($VsixFilePath);
$targetVsixFilePath = [System.IO.Path]::Combine($npmBinDir, $vsixFileName);
if (-not (Test-Path $targetVsixFilePath)) {
    # Create the target directory if it doesn't exist
    $targetVsixDir = [System.IO.Path]::GetDirectoryName($targetVsixFilePath)
    if (-not (Test-Path $targetVsixDir)) {
        Write-Verbose "Creating target directory: $targetVsixDir";
        New-Item -ItemType Directory -Path $targetVsixDir -Force | Write-Verbose;
        Write-Verbose "Created target directory: $targetVsixDir";
    }
    # Copy the VSIX file to the target directory
    Write-Verbose "Copying VSIX file to $targetVsixFilePath";
    Copy-Item -Path $VsixFilePath -Destination $targetVsixFilePath -Force | Write-Verbose;
    Write-Verbose "Copied VSIX file to $targetVsixFilePath";
}
else {
    Write-Verbose "VSIX file already exists in the output directory: $targetVsixFilePath";
}

############################################################################################################
## Unzip the VSIX file
############################################################################################################

# Extract the zip archive on disk
Invoke-VsixExtraction `
    -VsixFilePath $VsixFilePath `
    -OutputDir $extractedExtensionDir `
    @VerboseArgument | Write-Verbose;

############################################################################################################
## Read the VS Code extension's package.json and extension.vsixmanifest files
############################################################################################################

# Read the contents from package.json into a JSON object in a variable packageJson
Write-Verbose "Reading extension manifest from $vsCodeManifestFilePath";
$packageJson = Get-Content -Path $vsCodeManifestFilePath -Raw | ConvertFrom-Json -Depth 100;

# Read the XML manifest from extension.vsixmanifest into a variable vsixManifest
Write-Verbose "Reading extension manifest from $vsixManifestFilePath";
$vsixManifest = [xml](Get-Content -Path $vsixManifestFilePath);

############################################################################################################
## Get the VS Code extension identity properties (PublisherName, ExtensionName, Version, TargetPlatform)
############################################################################################################

Write-Verbose "Reading extension identity from $vsixManifestFilePath";

$PublisherName = $vsixManifest.PackageManifest.Metadata.Identity.Publisher;
$ExtensionName = $vsixManifest.PackageManifest.Metadata.Identity.Id;
$Version = $vsixManifest.PackageManifest.Metadata.Identity.Version;
$TargetPlatform = $vsixManifest.PackageManifest.Metadata.Identity.TargetPlatform;
$VSCodeExtensionId = "$PublisherName.$ExtensionName";
$NpmPackageId = $VSCodeExtensionId.ToLowerInvariant();

Write-Verbose "Extension publisher name: $PublisherName";
Write-Verbose "Extension name: $ExtensionName";
Write-Verbose "Extension version: $Version";

if ($TargetPlatform) {
    Write-Verbose "Target platform: $TargetPlatform";
    Write-Host "VS Code extension identity: $VSCodeExtensionId v$Version ($TargetPlatform)" -ForegroundColor Green;
    $NpmPackageVersion = "$Version$NpmVersionTargetPlatformSeparator$TargetPlatform";
}
else {
    Write-Verbose "Target platform: universal";
    Write-Host "VS Code extension identity: $VSCodeExtensionId v$Version (universal)" -ForegroundColor Green;
    $NpmPackageVersion = $Version;
}

Write-Host "NPM package identity: $NpmPackageId@$NpmPackageVersion" -ForegroundColor Green;

############################################################################################################
## Construct the npm publish request payload and modify the npm package.json to improve Azure Artifacts UX.
############################################################################################################

# Override the npm package.json package name to include the publisher name and match the VS Marketplace behavior for VS Code extensions
$packageJson.name = $NpmPackageId;

# Set the targetplatform string as a prerelease tag on the version
$packageJson.version = $NpmPackageVersion;

# Some VS Code extension publishers use placeholders in their package.json properties.
# We need to replace them with the actual values from the vsixmanifest
$packageJson.description = $vsixManifest.PackageManifest.Metadata.Description.InnerText;
$packageJson.displayName = $vsixManifest.PackageManifest.Metadata.DisplayName;

# If the packageJson has an extensionDependencies property set, copy it to the dependencies property
if ($packageJson.extensionDependencies) {
    $packageJson.dependencies = $packageJson.extensionDependencies;
}

# If the packageJson has a files property set, remove it and use the default (include all files)
if ($packageJson.PSObject.Properties['files']) {
    $packageJson.PSObject.Properties.Remove('files');
}

# If the packageJson has an icon property set, copy it to the root of the npm package
if ($packageJson.PSObject.Properties['icon']) {
    $iconPath = [System.IO.Path]::Combine($extractedExtensionManifestDir, $packageJson.icon);
    if (Test-Path $packageJson.icon) {
        Copy-Item -Path $iconPath -Destination $OutputDir -Force | Write-Verbose;
    }
}

# If a readme is available, copy it to the root of the npm package
Write-Verbose "Copying readme to $OutputDir"
Copy-AssetToNpmRoot -AssetPaths $validReadmeFileNames -SourceDirectory $extractedExtensionManifestDir -TargetDirectory $OutputDir @VerboseArgument | Write-Verbose;
Write-Verbose "Copied readme to $OutputDir"

# If a changelog is available, copy it to the root of the npm package
Write-Verbose "Copying changelog to $OutputDir"
Copy-AssetToNpmRoot -AssetPaths $validChangelogFileNames -SourceDirectory $extractedExtensionManifestDir -TargetDirectory $OutputDir @VerboseArgument | Write-Verbose;
Write-Verbose "Copied changelog to $OutputDir"

# If a license is available, copy it to the root of the npm package
Write-Verbose "Copying license to $OutputDir";
Copy-AssetToNpmRoot -AssetPaths $validLicenseFileNames -SourceDirectory $extractedExtensionManifestDir -TargetDirectory $OutputDir @VerboseArgument | Write-Verbose;
Write-Verbose "Copied license to $OutputDir";

# List of properties to remove from the npm package.json
$propertiesToRemove = @('activationEvents', 'brokeredServices', 'contributes', 'devDependencies', 'extensionDependencies', 'optionalDependencies', 'private', 'resolutions', 'scripts');
foreach ($property in $propertiesToRemove) {
    if ($packageJson.PSObject.Properties[$property]) {
        Write-Verbose "Removing property $property from package.json";
        $packageJson.PSObject.Properties.Remove($property);
        Write-Verbose "Removed property $property from package.json";
    }
}

$payload = $packageJson | ConvertTo-Json -Depth 100;
$payload | Out-File -FilePath $payloadFilePath -Encoding utf8;

Write-Verbose "Payload written to $payloadFilePath";

# Clean up the extracted extension directory
if (Test-Path $extractedExtensionDir) {
    Remove-Item -Path $extractedExtensionDir -Recurse -Force -ErrorAction SilentlyContinue;
}

############################################################################################################
## Publish the extension to the Azure DevOps NPM registry
############################################################################################################

Write-Verbose "Output directory: $OutputDir";
Write-Verbose "Payload file: $payloadFilePath";
Write-Verbose "VSIX file: $targetVsixFilePath";

# Authenticate to the feed
Write-Verbose "Authenticating to the feed: $DestinationFeed";
Set-NpmAuthentication -OutputDir $OutputDir -DestinationFeed $DestinationFeed @VerboseArgument | Write-Host;

# Move to the output directory
Push-Location $OutputDir;

Publish-Npm `
    -NpmPackageId $NpmPackageId `
    -NpmPackageVersion $NpmPackageVersion `
    -Version $Version `
    -TargetPlatform $TargetPlatform `
    -DestinationFeed $DestinationFeed `
    -OutputDir $OutputDir `
    @VerboseArgument;

Pop-Location;

# SIG # Begin signature block
# MIIoKgYJKoZIhvcNAQcCoIIoGzCCKBcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCApDk6yAVTK/Ql2
# csaNQwVpdRBHf20u+OYJCpU/NdH2b6CCDXYwggX0MIID3KADAgECAhMzAAAEhV6Z
# 7A5ZL83XAAAAAASFMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjUwNjE5MTgyMTM3WhcNMjYwNjE3MTgyMTM3WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDASkh1cpvuUqfbqxele7LCSHEamVNBfFE4uY1FkGsAdUF/vnjpE1dnAD9vMOqy
# 5ZO49ILhP4jiP/P2Pn9ao+5TDtKmcQ+pZdzbG7t43yRXJC3nXvTGQroodPi9USQi
# 9rI+0gwuXRKBII7L+k3kMkKLmFrsWUjzgXVCLYa6ZH7BCALAcJWZTwWPoiT4HpqQ
# hJcYLB7pfetAVCeBEVZD8itKQ6QA5/LQR+9X6dlSj4Vxta4JnpxvgSrkjXCz+tlJ
# 67ABZ551lw23RWU1uyfgCfEFhBfiyPR2WSjskPl9ap6qrf8fNQ1sGYun2p4JdXxe
# UAKf1hVa/3TQXjvPTiRXCnJPAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUuCZyGiCuLYE0aU7j5TFqY05kko0w
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwNTM1OTAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBACjmqAp2Ci4sTHZci+qk
# tEAKsFk5HNVGKyWR2rFGXsd7cggZ04H5U4SV0fAL6fOE9dLvt4I7HBHLhpGdE5Uj
# Ly4NxLTG2bDAkeAVmxmd2uKWVGKym1aarDxXfv3GCN4mRX+Pn4c+py3S/6Kkt5eS
# DAIIsrzKw3Kh2SW1hCwXX/k1v4b+NH1Fjl+i/xPJspXCFuZB4aC5FLT5fgbRKqns
# WeAdn8DsrYQhT3QXLt6Nv3/dMzv7G/Cdpbdcoul8FYl+t3dmXM+SIClC3l2ae0wO
# lNrQ42yQEycuPU5OoqLT85jsZ7+4CaScfFINlO7l7Y7r/xauqHbSPQ1r3oIC+e71
# 5s2G3ClZa3y99aYx2lnXYe1srcrIx8NAXTViiypXVn9ZGmEkfNcfDiqGQwkml5z9
# nm3pWiBZ69adaBBbAFEjyJG4y0a76bel/4sDCVvaZzLM3TFbxVO9BQrjZRtbJZbk
# C3XArpLqZSfx53SuYdddxPX8pvcqFuEu8wcUeD05t9xNbJ4TtdAECJlEi0vvBxlm
# M5tzFXy2qZeqPMXHSQYqPgZ9jvScZ6NwznFD0+33kbzyhOSz/WuGbAu4cHZG8gKn
# lQVT4uA2Diex9DMs2WHiokNknYlLoUeWXW1QrJLpqO82TLyKTbBM/oZHAdIc0kzo
# STro9b3+vjn2809D0+SOOCVZMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGgowghoGAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAASFXpnsDlkvzdcAAAAABIUwDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIAV51OPkNTwXowRGVeLOFn+Z
# vA79nP7B8HncwMEjoQVHMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAaeavYtvcqE1I8b2gfLjcY3wRHvuIyBxHm8c/YuVzY6+PCo7vQwUyt+iZ
# vwPN6+I9Q4PYlOCw5FN4o8WksxCX9r3hnS8P726dHJRwsLCBtReC2rNDBIVMt9DI
# QH7b9SVVzO5DjoYeufCmwzLX4Wy9Aia6RS78Nu96b6ojjKR6SK5MPpkknd0NIZ2m
# A7a0SQfoXQwkIqYsSkIhEI+PiTJafT69//70CSk7imHvnovIRT85cXBkH0qaVH9g
# Etmhk0duBc0GHxQeksIYiFU1VDH8AXPX6cgLt3yoYWl0jupEEv8ihCt7VW1hsLTN
# 5m3bkm5okdiEIJjF3YO4O7b2WRKW56GCF5QwgheQBgorBgEEAYI3AwMBMYIXgDCC
# F3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsq
# hkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCBIq7zcKwdH/iGHqjA9hn+klFu+DKJo8gtGtgJdAj66zgIGaPtY8TF6
# GBMyMDI1MTEwNzIyMTEzOC43ODlaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046OTYwMC0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghHqMIIHIDCCBQigAwIBAgITMwAAAgTY4A4HlzJYmAABAAACBDANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNTAxMzAxOTQy
# NDdaFw0yNjA0MjIxOTQyNDdaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046OTYwMC0wNUUwLUQ5NDcxJTAjBgNV
# BAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDw3Sbcee2d66vkWGTIXhfGqqgQGxQXTnq44XlUvNzF
# St7ELtO4B939jwZFX7DrRt/4fpzGNkFdGpc7EL5S86qKYv360eXjW+fIv1lAqDD3
# 1d/p8Ai9/AZz8M95zo0rDpK2csz9WAyR9FtUDx52VOs9qP3/pgpHvgUvD8s6/3KN
# ITzms8QC1tJ3TMw1cRn9CZgVIYzw2iD/ZvOW0sbF/DRdgM8UdtxjFIKTXTaI/bJh
# sQge3TwayKQ2j85RafFFVCR5/ChapkrBQWGwNFaPzpmYN46mPiOvUxriISC9nQ/G
# rDXUJWzLDmchrmr2baABJevvw31UYlTlLZY6zUmjkgaRfpozd+Glq9TY2E3Dglr6
# PtTEKgPu2hM6v8NiU5nTvxhDnxdmcf8UN7goeVlELXbOm7j8yw1xM9IyyQuUMWko
# rBaN/5r9g4lvYkMohRXEYB0tMaOPt0FmZmQMLBFpNRVnXBTa4haXvn1adKrvTz8V
# lfnHxkH6riA/h2AlqYWhv0YULsEcHnaDWgqA29ry+jH097MpJ/FHGHxk+d9kH2L5
# aJPpAYuNmMNPB7FDTPWAx7Apjr/J5MhUx0i07gV2brAZ9J9RHi+fMPbS+Qm4AonC
# 5iOTj+dKCttVRs+jKKuO63CLwqlljvnUCmuSavOX54IXOtKcFZkfDdOZ7cE4DioP
# 1QIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFBp1dktAcGpW/Km6qm+vu4M1GaJfMB8G
# A1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCG
# Tmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4w
# XAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQD
# AgeAMA0GCSqGSIb3DQEBCwUAA4ICAQBecv6sRw2HTLMyUC1WJJ+FR+DgA9Jkv0lG
# sIt4y69CmOj8R63oFbhSmcdpakxqNbr8v9dyTb4RDyNqtohiiXbtrXmQK5X7y/Q+
# +F0zMotTtTpTPvG3eltyV/LvO15mrLoNQ7W4VH58aLt030tORxs8VnAQQF5BmQQM
# Oua+EQgH4f1F4uF6rl3EC17JBSJ0wjHSea/n0WYiHPR0qkz/NRAf8lSUUV0gbIMa
# wGIjn7+RKyCr+8l1xdNkK/F0UYuX3hG0nE+9Wc0L4A/enluUN7Pa9vOV6Vi3BOJS
# T0RY/ax7iZ45leM8kqCw7BFPcTIkWzxpjr2nCtirnkw7OBQ6FNgwIuAvYNTU7r60
# W421YFOL5pTsMZcNDOOsA01xv7ymCF6zknMGpRHuw0Rb2BAJC9quU7CXWbMbAJLd
# Z6XINKariSmCX3/MLdzcW5XOycK0QhoRNRf4WqXRshEBaY2ymJvHO48oSSY/kpuY
# vBS3ljAAuLN7Rp8jWS7t916paGeE7prmrP9FJsoy1LFKmFnW+vg43ANhByuAEXq9
# Cay5o7K2H5NFnR5wj/SLRKwK1iyUX926i1TEviEiAh/PVyJbAD4koipig28p/6HD
# uiYOZ0wUkm/a5W8orIjoOdU3XsJ4i08CfNp5I73CsvB5QPYMcLpF9NO/1LvoQAw3
# UPdL55M5HTCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZI
# hvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# MjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAy
# MDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25Phdg
# M/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPF
# dvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6
# GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBp
# Dco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50Zu
# yjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3E
# XzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0
# lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1q
# GFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ
# +QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PA
# PBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkw
# EgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxG
# NSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARV
# MFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAK
# BggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMC
# AYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvX
# zpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20v
# cGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYI
# KwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG
# 9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0x
# M7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmC
# VgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449
# xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wM
# nosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDS
# PeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2d
# Y3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxn
# GSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+Crvs
# QWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokL
# jzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL
# 6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNN
# MIICNQIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEn
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjk2MDAtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQC6
# PYHRw9+9SH+1pwy6qzVG3k9lbqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7LhKaDAiGA8yMDI1MTEwNzEwMzcy
# OFoYDzIwMjUxMTA4MTAzNzI4WjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDsuEpo
# AgEAMAcCAQACAi4ZMAcCAQACAhNKMAoCBQDsuZvoAgEAMDYGCisGAQQBhFkKBAIx
# KDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZI
# hvcNAQELBQADggEBACrImVgHEiuWtMH5rAYuC6lpQCx+eNZUdvevOuqsJdiPLD9f
# LCx9fDoa0KQ0nF/RIvSUdP3MOGDYXQJ5CHY+okdQVb6J/aj7+fM3l7xly8GYMAAV
# Ehg3UieNN+nq7F1DY/K/dhIHY787LYCmI85JGHya2Z1zHp4wtWar2dr6ZYKtJPvV
# /n1gOcHD+aWIEgCJ24aoXbQU/V653/fN8i48/e1CI8pvKupm1nxXPKxZ6Gb61O4l
# GLocx2Rr6ucdbqw96aIFGjRFzGjr1DR3HFAal5czQ40fA8oM2udjIlPjAvIz3TFN
# Hx+R4zJwEnCMA4UekVmyzTeYX2yjlIiMgUGmq+8xggQNMIIECQIBATCBkzB8MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAgTY4A4HlzJYmAABAAACBDAN
# BglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8G
# CSqGSIb3DQEJBDEiBCCYNI16PhTs8ki2xwDDhuwjuX7qgq638qo8a9z2oRq59DCB
# +gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIPnteGX9Wwq8VdJM6mjfx1GEJsu7
# /6kU6l0SS5rcebn+MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAAIE2OAOB5cyWJgAAQAAAgQwIgQg6H6C15qSpwXOvO/Q9S947ap2t6rl
# VAAP4FuMYciHFggwDQYJKoZIhvcNAQELBQAEggIAQJ68DJ9cI35cTFfkKjJBOTKK
# UbUo8rCYacJelXMmS3kEd/WwL9LzGrehqRKVUsG2HqIfif6drzkiWjaGGMGBckbk
# qoWaLWHqTeA2jDGbi5LBR59zUu48qcslsi01gcQAESYJZl23Rv7FDS/Mxnf4fowE
# FKUdGp6uLQRr83EFBsCSllWioGgL1L8ZbvCOR8IFNbj4Ppdc56V6ghpkoyReFFht
# AVESJS12PS5XjiJrNIRP+tfAorK9c/yftFQ1psnUBJts+qbpT1TM449zLP9pKYxu
# K3/elr3boRJMVSkRmarnrXXlfzDsRFhLKr3ZSbuqeGwK8Ta0gonAC0sewRNSYS7x
# +XBn4Vrmd+FMLPPuEHCh2JObElDeLPkVdLUM5T2+rtc9MhjZ+SrnO1Gx73LB4WQ0
# StRH+2fj6fKT+2h0jV6NvBG621liPRQpTV6ltbcjLplDRr2VbsOuZkvKcehn7Swp
# KHIFt3cXBPVIDGQfj4+D0fa7TDS39E/Tqs/178Awi5tEsXr5WJrP5hNcCAMx143A
# Zg+v2WnYZcwaW+eJGu/+8STSqvIlcGYvvXl58uFyy/5jOmM5drw6fMs0ddFAEbDi
# 7+oiiD9aGFqz9m2TkYO0uZW4kOd/iLciQI6oGO+iu4jfGneTWzUQNA+hBnGQA9GR
# G99D+7VXy8SWhkwzd8A=
# SIG # End signature block
