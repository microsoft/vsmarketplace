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
# MIIoUgYJKoZIhvcNAQcCoIIoQzCCKD8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCApDk6yAVTK/Ql2
# csaNQwVpdRBHf20u+OYJCpU/NdH2b6CCDYUwggYDMIID66ADAgECAhMzAAAEhJji
# EuB4ozFdAAAAAASEMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjUwNjE5MTgyMTM1WhcNMjYwNjE3MTgyMTM1WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDtekqMKDnzfsyc1T1QpHfFtr+rkir8ldzLPKmMXbRDouVXAsvBfd6E82tPj4Yz
# aSluGDQoX3NpMKooKeVFjjNRq37yyT/h1QTLMB8dpmsZ/70UM+U/sYxvt1PWWxLj
# MNIXqzB8PjG6i7H2YFgk4YOhfGSekvnzW13dLAtfjD0wiwREPvCNlilRz7XoFde5
# KO01eFiWeteh48qUOqUaAkIznC4XB3sFd1LWUmupXHK05QfJSmnei9qZJBYTt8Zh
# ArGDh7nQn+Y1jOA3oBiCUJ4n1CMaWdDhrgdMuu026oWAbfC3prqkUn8LWp28H+2S
# LetNG5KQZZwvy3Zcn7+PQGl5AgMBAAGjggGCMIIBfjAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUBN/0b6Fh6nMdE4FAxYG9kWCpbYUw
# VAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwMDEyKzUwNTM2MjAfBgNVHSMEGDAW
# gBRIbmTlUAXTgqoXNzcitW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIw
# MTEtMDctMDguY3JsMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDEx
# XzIwMTEtMDctMDguY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIB
# AGLQps1XU4RTcoDIDLP6QG3NnRE3p/WSMp61Cs8Z+JUv3xJWGtBzYmCINmHVFv6i
# 8pYF/e79FNK6P1oKjduxqHSicBdg8Mj0k8kDFA/0eU26bPBRQUIaiWrhsDOrXWdL
# m7Zmu516oQoUWcINs4jBfjDEVV4bmgQYfe+4/MUJwQJ9h6mfE+kcCP4HlP4ChIQB
# UHoSymakcTBvZw+Qst7sbdt5KnQKkSEN01CzPG1awClCI6zLKf/vKIwnqHw/+Wvc
# Ar7gwKlWNmLwTNi807r9rWsXQep1Q8YMkIuGmZ0a1qCd3GuOkSRznz2/0ojeZVYh
# ZyohCQi1Bs+xfRkv/fy0HfV3mNyO22dFUvHzBZgqE5FbGjmUnrSr1x8lCrK+s4A+
# bOGp2IejOphWoZEPGOco/HEznZ5Lk6w6W+E2Jy3PHoFE0Y8TtkSE4/80Y2lBJhLj
# 27d8ueJ8IdQhSpL/WzTjjnuYH7Dx5o9pWdIGSaFNYuSqOYxrVW7N4AEQVRDZeqDc
# fqPG3O6r5SNsxXbd71DCIQURtUKss53ON+vrlV0rjiKBIdwvMNLQ9zK0jy77owDy
# XXoYkQxakN2uFIBO1UNAvCYXjs4rw3SRmBX9qiZ5ENxcn/pLMkiyb68QdwHUXz+1
# fI6ea3/jjpNPz6Dlc/RMcXIWeMMkhup/XEbwu73U+uz/MIIHejCCBWKgAwIBAgIK
# YQ6Q0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlm
# aWNhdGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEw
# OTA5WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYD
# VQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+la
# UKq4BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc
# 6Whe0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4D
# dato88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+
# lD3v++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nk
# kDstrjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6
# A4aN91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmd
# X4jiJV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL
# 5zmhD+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zd
# sGbiwZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3
# T8HhhUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS
# 4NaIjAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRI
# bmTlUAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAL
# BgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBD
# uRQFTuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEF
# BQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1h
# cnljcHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkA
# YwB5AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn
# 8oalmOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7
# v0epo/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0b
# pdS1HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/
# KmtYSWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvy
# CInWH8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBp
# mLJZiWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJi
# hsMdYzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYb
# BL7fQccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbS
# oqKfenoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sL
# gOppO6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtX
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCGiMwghofAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAASEmOIS4HijMV0AAAAA
# BIQwDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIAV5
# 1OPkNTwXowRGVeLOFn+ZvA79nP7B8HncwMEjoQVHMEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAtzjKkDVJKns5kBAcjh+ew5rYCrONa/nGMIJA
# zTxz3Q5sJuXt40qHPpXQwAS5OSKkRLdTFsaC9Ifwuyp4DL2x4HhU1cnIUcf13b5T
# XEBZA8lOh8Td7Wi2TJWiRZeQAFJIn6HcmSr4Xo0qtywq20p/y19siPxczS4XqNoi
# 0b6ym9rtPcLoho1pNW5xCj63QdocNPePRNTW9St/DwtSyJA8uOWHFCwLfA97TGl2
# TmD5cwaU13EUGSnoBl6dAy3IBsAB89ATK5A3lgP7fJrCVtNpE6e0VP4AJ9Nq3wMo
# 2qbqRJHaBm84N3xO7BKrCKohoXZA4CeG2wiXoaKjt44fEPl5G6GCF60wghepBgor
# BgEEAYI3AwMBMYIXmTCCF5UGCSqGSIb3DQEHAqCCF4YwgheCAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFaBgsqhkiG9w0BCRABBKCCAUkEggFFMIIBQQIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCA0FVGmwnj23wV/0Q543TWwhacHxaNkPk8K
# oJhiQlQbRQIGaPKRRxQhGBMyMDI1MTAyMDIxMzUxMS4wNjRaMASAAgH0oIHZpIHW
# MIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsT
# Hm5TaGllbGQgVFNTIEVTTjo2NTFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEfswggcoMIIFEKADAgECAhMzAAACFRgD
# 04EHJnxTAAEAAAIVMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMB4XDTI1MDgxNDE4NDgyMFoXDTI2MTExMzE4NDgyMFowgdMxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jv
# c29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNoaWVs
# ZCBUU1MgRVNOOjY1MUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# w3HV3hVxL0lEYPV03XeNKZ517VIbgexhlDPdpXwDS0BYtxPwi4XYpZR1ld0u6cr2
# Xjuugdg50DUx5WHL0QhY2d9vkJSk02rE/75hcKt91m2Ih287QRxRMmFu3BF6466k
# 8qp5uXtfe6uciq49YaS8p+dzv3uTarD4hQ8UT7La95pOJiRqxxd0qOGLECvHLEXP
# XioNSx9pyhzhm6lt7ezLxJeFVYtxShkavPoZN0dOCiYeh4KgoKoyagzMuSiLCiMU
# W4Ue4Qsm658FJNGTNh7V5qXYVA6k5xjw5WeWdKOz0i9A5jBcbY9fVOo/cA8i1byt
# zcDTxb3nctcly8/OYeNstkab/Isq3Cxe1vq96fIHE1+ZGmJjka1sodwqPycVp/2t
# b+BjulPL5D6rgUXTPF84U82RLKHV57bB8fHRpgnjcWBQuXPgVeSXpERWimt0NF2l
# COLzqgrvS/vYqde5Ln9YlKKhAZ/xDE0TLIIr6+I/2JTtXP34nfjTENVqMBISWcak
# IxAwGb3RB5yHCxynIFNVLcfKAsEdC5U2em0fAvmVv0sonqnv17cuaYi2eCLWhoK1
# Ic85Dw7s/lhcXrBpY4n/Rl5l3wHzs4vOIhu87DIy5QUaEupEsyY0NWqgI4BWl6v1
# wgse+l8DWFeUXofhUuCgVTuTHN3K8idoMbn8Q3edUIECAwEAAaOCAUkwggFFMB0G
# A1UdDgQWBBSJIXfxcqAwFqGj9jdwQtdSqadj1zAfBgNVHSMEGDAWgBSfpxVdAF5i
# XYP05dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENB
# JTIwMjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1Ud
# JQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsF
# AAOCAgEAd42HtV+kGbvxzLBTC5O7vkCIBPy/BwpjCzeL53hAiEOebp+VdNnwm9GV
# CfYq3KMfrj4UvKQTUAaS5Zkwe1gvZ3ljSSnCOyS5OwNu9dpg3ww+QW2eOcSLkyVA
# WFrLn6Iig3TC/zWMvVhqXtdFhG2KJ1lSbN222csY3E3/BrGluAlvET9gmxVyyxNy
# 59/7JF5zIGcJibydxs94JL1BtPgXJOfZzQ+/3iTc6eDtmaWT6DKdnJocp8wkXKWP
# IsBEfkD6k1Qitwvt0mHrORah75SjecOKt4oWayVLkPTho12e0ongEg1cje5fxSZG
# thrMrWKvI4R7HEC7k8maH9ePA3ViH0CVSSOefaPTGMzIhHCo5p3jG5SMcyO3eA9u
# EaYQJITJlLG3BwwGmypY7C/8/nj1SOhgx1HgJ0ywOJL9xfP4AOcWmCfbsqgGbCaC
# 7WH5sINdzfMar8V7YNFqkbCGUKhc8GpIyE+MKnyVn33jsuaGAlNRg7dVRUSoYLJx
# vUsw9GOwyBpBwbE9sqOLm+HsO00oF23PMio7WFXcFTZAjp3ujihBAfLrXICgGOHP
# dkZ042u1LZqOcnlr3XzvgMe+mPPyasW8f0rtzJj3V5E/EKiyQlPxj9Mfq2x9himn
# lXWGZCVPeEBROrNbDYBfazTyLNCOTsRtksOSV3FBtPnpQtLN754wggdxMIIFWaAD
# AgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3Nv
# ZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIy
# MjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5
# vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64
# NmeFRiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhu
# je3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl
# 3GoPz130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPg
# yY9+tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I
# 5JasAUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2
# ci/bfV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/
# TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy
# 16cg8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y
# 1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6H
# XtqPnhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMB
# AAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQW
# BBSfpxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30B
# ATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3Bz
# L0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYB
# BAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMB
# Af8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBL
# oEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMv
# TWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggr
# BgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNS
# b29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcNAQELBQADggIBAJ1Vffwq
# reEsH2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27
# DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYAA7AFvonoaeC6Ce5732pv
# vinLbtg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9Ak
# vUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWK
# NsIdw2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2
# kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+
# c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep
# 8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+Dvk
# txW/tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1Zyvg
# DbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/
# 2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIDVjCCAj4CAQEwggEBoYHZpIHW
# MIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsT
# Hm5TaGllbGQgVFNTIEVTTjo2NTFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUAj6eTejbuYE1I
# fjbfrt6tXevCUSCggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MDANBgkqhkiG9w0BAQsFAAIFAOyhBA0wIhgPMjAyNTEwMjAxODU1MDlaGA8yMDI1
# MTAyMTE4NTUwOVowdDA6BgorBgEEAYRZCgQBMSwwKjAKAgUA7KEEDQIBADAHAgEA
# AgIRTzAHAgEAAgIUrTAKAgUA7KJVjQIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgor
# BgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBCwUA
# A4IBAQDOZJHA10PMPQWAdCbGZGZctBWn8rTGkJpmyvUeNHCQJIKdfRbwXtZcf580
# ePfy1JRvsFKGM3vjtIYTcQyRMwEv9D7uZ0Axxk7dHETihG9std/f9zZp0KaPHDq3
# JDwz1URf5kb3TVVpn8fTINoMnMMZKhDIQgcNjg9sgZqPUoXloJ/iVFAUfl0vk/r+
# kdexRTOoYxv4KnEOSaddQ0fZ7v+bSV6tAMm4V9ArjyELhLjqcF9J4HDuGJD5g6w3
# HWKaJmOWiXhf9S9vCjOWbwRrRU500iBP3RxwmCn56u0tjEQRhxGyBuJFe0RwMdqN
# GOsuOCIIHJHdrWD46b06rCj5IlbXMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAIVGAPTgQcmfFMAAQAAAhUwDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQgJytsim696ag8isgCr7AtB/mPIXO8wvxWDeOQ6ryRZx0wgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCBwEPR2PDrTFLcrtQsKrUi7oz5JNRCF/KRHMihS
# Ne7sijCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAC
# FRgD04EHJnxTAAEAAAIVMCIEINOVnmGt3doVAnCqSDgGQoYhXDdFFqoFpCDaEkJr
# Vkq8MA0GCSqGSIb3DQEBCwUABIICADN1qRipYtTEiHF3l0+ujwFY2OxDKJATjslC
# x7i2NRCxQibr3tKWpIhnJo51j78u5Z7+GcmovMbihsdBAz+FpMGcqT5xF0PJm+cS
# qygg/a5bVAr7xSs5SQ1DU4CfuTJYCshjQyVNNSYsmurvd1sAXwcUixIYvC9PsYQx
# uPzy7E8BmcYmHOauecVD20tCUCelOOkwF3BqeJ457pqGC7HjHcwvKZAx8AQwSMKe
# 1AWbjL5J0B4F9pldhaT3CeGer0uNp8j0owO1CKVtI1fec5m+/vabBvJtGmZcYIMV
# iMHZozOuBAWGX+LUs4Y6ro+Nry2bEC3R9lQi09rGe6bu1jCx3e0TuJXE9BauTh8W
# l+xxohCcb1P7FmHhVUd2ztQ4vAr2eae5VNK91Xf9tjYtKI9bZrW9fWuEFgZahLlI
# ghVP0ha/3uzq/fHEIQKRLOHpwrZbxhNuUEg+GM407zNd3LNDA5aoo4qt5LE8ip43
# blSMRUVg5FDRuFkrxAYAad4XPzojHoQdFFWJRWuclPXaZuppBPAwwohrv4lV+kZ9
# mSJXMfmAWXxVZZc1A4XdDIaDEmRSrWznnadkUIP5WzYnpXFS7y8jE7iYNLhCtJEp
# YTARDR6S5y2ZOM2GRwyDmPRJBOB+Mqc7+QTymYJt4yVzZE/jvaZSDXAnSz5rYTxX
# CLHrpFkr
# SIG # End signature block
