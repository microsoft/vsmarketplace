// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace SearchScorer.Common
{
    /// <summary>
    /// Set of flags that can be associated with a given extension. These flags
    /// apply to all versions of the extension and not to a specific version.
    /// </summary>
    [Flags]
    public enum PublishedExtensionFlags
    {
        /// <summary>
        /// No flags exist for this extension.
        /// </summary>
        None = 0x0000,

        /// <summary>
        /// The Disabled flag for an extension means the extension can't be 
        /// changed and won't be used by consumers. The disabled flag is managed
        /// by the service and can't be supplied by the Extension Developers.
        /// </summary>
        Disabled = 0x0001,

        /// <summary>
        /// BuiltIn Extension are available to all Tenants. An explicit registration
        /// is not required. This attribute is reserved and can't be supplied by
        /// Extension Developers.
        /// 
        /// BuiltIn extensions are by definition Public. There is no need to set
        /// the public flag for extensions marked BuiltIn.
        /// </summary>
        BuiltIn = 0x0002,

        /// <summary>
        /// This extension has been validated by the service. The extension
        /// meets the requirements specified. This attribute is reserved and can't
        /// be supplied by the Extension Developers. Validation is a process
        /// that ensures that all contributions are well formed. They meet the
        /// requirements defined by the contribution type they are extending.
        /// Note this attribute will be updated asynchronously as the extension
        /// is validated by the developer of the contribution type. There will
        /// be restricted access to the extension while this process is performed.
        /// </summary>
        Validated = 0x0004,

        /// <summary>
        /// Trusted extensions are ones that are given special capabilities. These
        /// tend to come from Microsoft and can't be published by the general
        /// public. 
        /// 
        /// Note: BuiltIn extensions are always trusted.
        /// </summary>
        Trusted = 0x0008,

        /// <summary>
        /// The Paid flag indicates that the commerce can be enabled for this extension.
        /// Publisher needs to setup Offer/Pricing plan in Azure. If Paid flag is set and a corresponding Offer is not available, 
        /// the extension will automatically be marked as Preview. If the publisher intends to make the extension Paid in the future, 
        /// it is mandatory to set the Preview flag. This is currently available only for VSTS extensions only.
        /// </summary>
        Paid = 0x0010,

        /// <summary>
        /// This extension registration is public, making its visibility open
        /// to the public. This means all tenants have the ability to install
        /// this extension. Without this flag the extension will be private and
        /// will need to be shared with the tenants that can install it.
        /// </summary>
        Public = 0x0100,

        /// <summary>
        /// This extension has multiple versions active at one time and version
        /// discovery should be done using the defined "Version Discovery" protocol
        /// to determine the version available to a specific user or tenant.
        /// 
        /// @TODO: Link to Version Discovery Protocol.
        /// </summary>
        MultiVersion = 0x0200,

        /// <summary>
        /// The system flag is reserved, and cant be used by publishers. 
        /// </summary>
        System = 0x0400,

        /// <summary>
        /// The Preview flag indicates that the extension is still under preview (not yet of "release" quality).
        /// These extensions may be decorated differently in the gallery and may have different policies applied to them.
        /// </summary>
        Preview = 0x0800,

        /// <summary>
        /// The Unpublished flag indicates that the extension can't be installed/downloaded.
        /// Users who have installed such an extension can continue to use the extension.
        /// </summary>
        Unpublished = 0x1000,

        /// <summary>
        /// The Trial flag indicates that the extension is in Trial version.
        /// The flag is right now being used only with respect to Visual Studio extensions.
        /// </summary>
        Trial = 0x2000,

        /// <summary>
        /// The Locked flag indicates that extension has been locked from Marketplace.
        /// Further updates/acquisitions are not allowed on the extension until this is present.
        /// This should be used along with making the extension private/unpublished.
        /// </summary>
        Locked = 0x4000,

        /// <summary>
        /// This flag is set for extensions we want to hide from Marketplace home and search pages.
        /// This will be used to override the exposure of builtIn flags.
        /// </summary>
        Hidden = 0x8000
    }

    /// <summary>
    /// Set of flags that can be associated with a given extension version. These flags
    /// apply to a specific version of the extension.
    /// </summary>
    [Flags]
    public enum ExtensionVersionFlags
    {
        /// <summary>
        /// No flags exist for this version.
        /// </summary>
        None = 0x0000,

        /// <summary>
        /// The Validated flag for a version means the extension version
        /// has passed validation and can be used..
        /// </summary>
        Validated = 0x0001
    }


    /// <summary>
    /// </summary>
    public enum ExtensionDeploymentTechnology
    {
        Exe = 1,

        Msi,

        Vsix,

        ReferralLink
    }

    /// <summary>
    /// Set of flags used to determine which set of information is retrieved
    /// when reading published extensions
    /// </summary>
    [Flags]
    public enum ExtensionQueryFlags
    {
        /// <summary>
        /// None is used to retrieve only the basic extension details.
        /// </summary>
        None = 0x0,

        /// <summary>
        /// IncludeVersions will return version information for extensions returned
        /// </summary>
        IncludeVersions = 0x1,

        /// <summary>
        /// IncludeFiles will return information about which files were found
        /// within the extension that were stored independent of the manifest.
        /// When asking for files, versions will be included as well since files
        /// are returned as a property of the versions.
        /// 
        /// These files can be retrieved using the path to the file without
        /// requiring the entire manifest be downloaded.
        /// </summary>
        IncludeFiles = 0x2,

        /// <summary>
        /// Include the Categories and Tags that were added to the extension definition.
        /// </summary>
        IncludeCategoryAndTags = 0x4,

        /// <summary>
        /// Include the details about which accounts the extension has been shared
        /// with if the extension is a private extension.
        /// </summary>
        // IncludeSharedAccounts = 0x8,

        /// <summary>
        /// Include properties associated with versions of the extension
        /// </summary>
        IncludeVersionProperties = 0x10,

        /// <summary>
        /// Excluding non-validated extensions will remove any extension versions that
        /// either are in the process of being validated or have failed validation.
        /// </summary>
        ExcludeNonValidated = 0x20,

        /// <summary>
        /// Include the set of installation targets the extension has requested.
        /// </summary>
        IncludeInstallationTargets = 0x40,

        /// <summary>
        /// Include the base uri for assets of this extension
        /// </summary>
        IncludeAssetUri = 0x80,

        /// <summary>
        /// Include the statistics associated with this extension
        /// </summary>
        IncludeStatistics = 0x100,

        /// <summary>
        /// When retrieving versions from a query, only include the latest 
        /// version of the extensions that matched. This is useful when the
        /// caller doesn't need all the published versions. It will save a 
        /// significant size in the returned payload.
        /// </summary>
        IncludeLatestVersionOnly = 0x200,

        /// <summary>
        /// This flag switches the asset uri to use GetAssetByName instead of CDN
        /// When this is used, values of base asset uri and base asset uri fallback are switched
        /// When this is used, source of asset files are pointed to Gallery service always even if CDN is available
        /// </summary>
        UseFallbackAssetUri = 0x400,

        /// <summary>
        /// This flag is used to get all the metadata values associated with the extension. This is not applicable to VSTS or
        /// VSCode extensions and usage is only internal.
        /// </summary>
        IncludeMetadata = 0x800,

        /// <summary>
        /// This flag is used to indicate to return very small data for extension required by VS IDE. This flag is only compatible
        /// when querying is done by VS IDE
        /// </summary>
        IncludeMinimalPayloadForVsIde = 0x1000,

        /// <summary>
        /// This flag is used to get Lcid values associated with the extension. This is not applicable to VSTS 
        /// or VSCode extensions and usage is only internal
        /// </summary>
        IncludeLcids = 0x2000,

        /// <summary>
        /// AllAttributes is designed to be a mask that defines all sub-elements of
        /// the extension should be returned.
        /// 
        /// NOTE: This is not actually All flags. This is now locked to the set 
        /// defined since changing this enum would be a breaking change and would
        /// change the behavior of anyone using it. Try not to use this value when
        /// making calls to the service, instead be explicit about the options 
        /// required.
        /// </summary>
        // AllAttributes = IncludeVersions | IncludeFiles | IncludeCategoryAndTags | IncludeSharedAccounts | IncludeVersionProperties | IncludeInstallationTargets | IncludeAssetUri | IncludeStatistics | IncludeSharedOrganizations,
        AllAttributes = IncludeVersions | IncludeFiles | IncludeCategoryAndTags | IncludeVersionProperties | IncludeInstallationTargets | IncludeAssetUri | IncludeStatistics,
    }

    [Flags]
    // internal enum ExtensionQueryResultMetadataFlags
    public enum ExtensionQueryResultMetadataFlags
    {
        /// <summary>
        /// No metadata will be returned
        /// </summary>
        None = 0x0,

        /// <summary>
        /// Include the result total count metadata
        /// </summary>
        IncludeResultCount = 0x1,

        /// <summary>
        /// Include Categories metadata before applying any category filtering. This is useful to show the counts of other categories
        /// even though the user has filtered on one of the category
        /// </summary>
        IncludePreCategoryFilterCategories = 0x2,

        /// <summary>
        /// Include Categories metadata of the final result set
        /// </summary>
        IncludeResultSetCategories = 0x4,

        /// <summary>
        /// Include ProjectType metadata of the final result set. This is required for Programming Language Filter in Visual Studio IDE integration.
        /// </summary>
        IncludeResultSetProjectType = 0x8,

        /// <summary>
        /// Include the target platforms metadata. This is useful to show the counts of each TargetPlatform on the target platforms filter while searching VSCode extensions.
        /// </summary>
        IncludeTargetPlatforms = 0x10
    }

    /// <summary>
    /// Class to hold extension metadata value
    /// Currently this is internal. We may not want to make every metadata value public.
    /// </summary>
    // internal class ExtensionMetadata
    public class ExtensionMetadata
    {
        public String Key { get; set; }

        public String Value { get; set; }

        public ExtensionMetadata ShallowCopy()
        {
            return (ExtensionMetadata)this.MemberwiseClone();
        }
    }

    /// <summary>
    /// High-level information about the publisher, like id's and names
    /// </summary>
    public class PublisherFacts
    {
        public Guid PublisherId { get; set; }

        public String PublisherName { get; set; }

        public String DisplayName { get; set; }

        public PublisherFlags Flags { get; set; }

        public String Domain { get; set; }

        public Boolean IsDomainVerified { get; set; }
    }

    /// <summary>
    /// 
    /// </summary>
    [JsonConverter(typeof(PublishedExtensionConverter))]
    public class PublishedExtension
    {
        public PublisherFacts Publisher { get; set; }

        public Guid ExtensionId { get; set; }

        public String ExtensionName { get; set; }

        public String DisplayName { get; set; }

        public PublishedExtensionFlags Flags { get; set; }

        public DateTime LastUpdated { get; set; }

        /// <summary>
        /// Date on which the extension was first uploaded.
        /// </summary>
        public DateTime PublishedDate { get; set; }

        /// <summary>
        /// Date on which the extension first went public.
        /// </summary>
        public DateTime ReleaseDate { get; set; }

        public String ShortDescription { get; set; }

        public String LongDescription { get; set; }

        public List<ExtensionVersion> Versions { get; set; }

        public List<String> Categories { get; set; }

        public List<String> Tags { get; set; }


        public List<ExtensionStatistic> Statistics { get; set; }

        public List<InstallationTarget> InstallationTargets { get; set; }

        public List<ExtensionMetadata> Metadata { get; set; }

        public List<int> Lcids { get; set; }

        public ExtensionDeploymentTechnology DeploymentType { get; set; }

        public String GetProperty(
            String version,
            String propertyName)
        {
            if (!String.IsNullOrEmpty(version) && Versions != null && Versions.Count > 0)
            {
                ExtensionVersion extensionVersion = null;

                if (version.Equals("latest"))
                {
                    extensionVersion = Versions[0];
                }
                else
                {
                    foreach (ExtensionVersion ev in Versions)
                    {
                        if (ev.Version.Equals(version))
                        {
                            extensionVersion = ev;
                            break;
                        }
                    }
                }

                if (extensionVersion != null && extensionVersion.Properties != null)
                {
                    foreach (KeyValuePair<string, string> kvp in extensionVersion.Properties)
                    {
                        if (kvp.Key.Equals(propertyName))
                        {
                            return kvp.Value;
                        }
                    }
                }
            }

            return null;
        }

        public PublishedExtension ShallowCopy()
        {
            return (PublishedExtension)this.MemberwiseClone();
        }
    }

    /// <summary>
    /// 
    /// </summary>
    /// Note: We have created a copy of ExtensionVersion named ServerExtensionVersion. 
    /// If you are doing any change in  ExtensionVersion, please make sure that it should be added to ServerExtensionVersion too.
    [JsonConverter(typeof(ExtensionVersionConverter))]
    public class ExtensionVersion
    {
        internal Guid ExtensionId { get; set; }

        public String Version { get; set; }

        public String TargetPlatform { get; set; }

        public ExtensionVersionFlags Flags { get; set; }

        public DateTime LastUpdated { get; set; }

        public String VersionDescription { get; set; }

        public String ValidationResultMessage { get; set; }

        public List<ExtensionFile> Files { get; set; }

        public List<KeyValuePair<String, String>> Properties { get; set; }

        public List<ExtensionBadge> Badges { get; set; }

        public String AssetUri { get; set; }

        public String FallbackAssetUri { get; set; }

        public string CdnDirectory { get; set; }

        public bool IsCdnEnabled { get; set; }

        public ExtensionVersion ShallowCopy()
        {
            return (ExtensionVersion)this.MemberwiseClone();
        }

        public string GetCdnDirectory()
        {
            return CdnDirectory;
        }
    }

    /// <summary
    /// 
    /// </summary>
    public class ExtensionCategory
    {
        /// <summary>
        /// This is the internal name for a category
        /// </summary>
        public String CategoryName { get; set; }

        /// <summary>
        /// This is the internal name of the parent if this is associated with a parent
        /// </summary>
        public String ParentCategoryName { get; set; }

        /// <summary>
        /// The name of the products with which this category is associated to.
        /// </summary>
        public List<String> AssociatedProducts { get; set; }

        internal int MigratedId { get; set; }
        internal int ParentId { get; set; }
        public ExtensionCategory Parent { get; set; }

        /// <summary>
        /// This parameter is obsolete. Refer to LanguageTitles for language specific titles
        /// </summary>
        public String Language { get; set; }

        public Int32 CategoryId { get; set; }

        /// <summary>
        /// The list of all the titles of this category in various languages
        /// </summary>
        public List<CategoryLanguageTitle> LanguageTitles { get; set; }

        internal ExtensionCategory ShallowCopy()
        {
            return (ExtensionCategory)this.MemberwiseClone();
        }

        public string GetCategoryTitleForLanguage(string language)
        {
            if (LanguageTitles != null && LanguageTitles.Count > 0)
            {
                foreach (CategoryLanguageTitle categoryLanguageTitle in LanguageTitles)
                {
                    if (categoryLanguageTitle.Lang != null &&
                        categoryLanguageTitle.Lang.Equals(language, StringComparison.OrdinalIgnoreCase))
                    {
                        return categoryLanguageTitle.Title;
                    }
                }
            }

            return null;
        }
    }

    /// <summary>
    /// Definition of one title of a category
    /// </summary>
    public class CategoryLanguageTitle
    {
        /// <summary>
        /// The language for which the title is applicable
        /// </summary>
        public string Lang { get; set; }
        /// <summary>
        /// Actual title to be shown on the UI
        /// </summary>
        public string Title { get; set; }
        /// <summary>
        /// The language culture id of the lang parameter
        /// </summary>
        public int Lcid { get; set; }
    }
}
