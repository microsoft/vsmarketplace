// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace SearchScorer.Common
{
    internal class ExtensionSearchResult
    {
        public List<PublishedExtension> Results { get; set; }

        public List<ExtensionFilterResultMetadata> ResultMetadata { get; set; }
    }

    public enum SearchFilterType
    {
        /// <summary>
        /// SearchPhrase defines the search string provided by the user
        /// </summary>
        SearchPhrase = 0,

        /// <summary>
        /// Separate words to be searched for prefixes. 
        /// This covers the cases where the given word is a pharase and individual words can act as a matching prefix for an extension
        /// name e.g. Sonar Qube will be divided to Sonar and Qube and both will also be checked for prefix matches.
        /// </summary>
        SearchWord = 1,

        /// <summary>
        /// Filter for targets. The search results will be restricted based on given values.
        /// </summary>
        InstallationTarget = 2,

        /// <summary>
        /// Filters for categories. The search results will be restricted to only the defined categories.
        /// </summary>
        Category = 3,

        /// <summary>
        /// Filters for extension tags. The search results will be restricted to only the extesnions containing the given tags.
        /// </summary>
        Tag = 4,

        /// <summary>
        /// Filters for extension flags. The search results will be restricted to only the extesnions not containing the given flags.
        /// In case of having a particular flag in both IncludeWithFlags and ExcludeWithFlags,
        /// excludeFlags will remove the included extensions giving empty result for that flag.
        /// </summary>
        ExcludeExtensionsWithFlags = 5,

        /// <summary>
        /// Filter type to search for given value in extension name and restrict search results
        /// </summary>
        Name = 6,

        /// <summary>
        /// Filter type to search for given value in publisher names and restrict the search results
        /// </summary>
        Publisher = 7,

        /// <summary>
        /// Filter type to search for given value only in tags names
        /// </summary>
        TagName = 8,

        /// <summary>
        /// Filter type to signify actual user query given by user
        /// </summary>
        UserQuery = 9,

        /// <summary>
        /// Filters for extension flags. The search results will be restricted to only the extesnions containing the given flags.
        /// In case of having a particular flag in both IncludeWithFlags and ExcludeWithFlags,
        /// excludeFlags will remove the included extensions giving empty result for that flag.
        /// In case of multiple flags given in IncludeWithFlags in ORed fashion, extensions having any of the given flags will be included.
        /// </summary>
        IncludeExtensionsWithFlags = 10,

        /// <summary>
        /// Filters the result extensions based on the LCID value specified. This can be given multiple times.
        /// The extensions matching any one of them will be selected
        /// Only applicable for VS Extensions.
        /// </summary>
        Lcid = 11,

        /// <summary>
        /// Filtering based on the metadata for the extensions.
        /// The filter value should be of the form <keyname>:<value>
        /// This can be provided multiple times. Multiple filters with the same keyname will act as OR
        /// Different key names will act as AND
        /// The final filtered extensions will contain all the key names and matching values at least one of filter value among same
        /// key names. 
        /// The matching operator supported are Equal Or NotEqual only.
        /// Only applicable for VS Extensions
        /// </summary>
        Metadata = 12,

        /// Filter type for specifying the target version. This filter will be used along with InstallationTarget filter.
        /// The value should be a valid version string
        /// </summary>
        InstallationTargetVersion = 13,

        /// <summary>
        /// Filter type for specifying a range of installation target version. The filter will be used along with InstallationTarget filter.
        /// The value should be a pair of well formed version values separated by hyphen(-)
        /// </summary>
        InstallationTargetVersionRange = 14,

        /// <summary>
        /// This flag ensures that even private extensions are not excluded from the search results.
        /// This is internal and cannot be used from outside.
        /// </summary>
        IncludePrivateExtensions = 15,

        /// <summary>
        /// Filter type to search for exact match of publisher display names and restrict the search results
        /// </summary>
        ExactPublisherDisplayName = 16,

        /// <summary>
        /// Filters for extension publisher's flags. The search results will be restricted to only the extesnions from 
        /// publishers containing the given flags.
        /// In case of multiple flags given in IncludeWithFlags in ORed fashion, extensions with publishers having any of the given flags will be included.
        /// </summary>
        IncludeExtensionsWithPublisherFlags = 17,

        /// <summary>
        /// This flag ensures that private extensions shared with organization are included in the search results.
        /// </summary>
        [Obsolete]
        OrganizationSharedWith = 18,

        /// <summary>
        /// Filter for product architecture for VS IDE extensions. The search results will be restricted based on given values.
        /// </summary>
        ProductArchitecture = 19,

        /// <summary>
        /// Filter type for specifying target platform for VS Code extensions. The search result will be restricted to VS Code extensions supporting given target platform.
        /// </summary>
        TargetPlatform = 20
    }

    [Flags]
    internal enum SearchFeatureFlags
    {
        UseRatingsDownloadsForRelevance = 0x02,
        UseNewRelevanceForVSTS = 0x04,
        DoNotUseInternalNameForSearch = 0x08
    }

    public enum SearchFilterOperatorType
    {
        /// <summary>
        /// The filter adds the matching values to the result
        /// </summary>
        Or = 0,

        /// <summary>
        /// The filter restrict the result only to the matching values
        /// </summary>
        And = 1,

        /// <summary>
        /// Will check for equality for the given filter value. Applicable only for Metadata type filter
        /// </summary>
        Equal = 2,

        /// <summary>
        /// Will check for not equality for the given filter value. Applicable only for Metadata type filter
        /// </summary>
        NotEqual = 3
    }

    public class SearchCriteria
    {
        public SearchFilterType FilterType { get; set; }

        public String FilterValue { get; set; }

        public SearchFilterOperatorType OperatorType { get; set; }
    }

    /// <summary>
    /// ExtensionSearchParams defines the various parameters needed for search
    /// This is an internal structure and is filled based on given inputs by the caller of the API
    /// </summary>
    // internal class ExtensionSearchParams
    public class ExtensionSearchParams
    {
        public List<SearchCriteria> CriteriaList { get; set; }

        /// <summary>
        /// The page size that the user wants. Should be less than or equal to max supported page size.
        /// </summary>
        public Int32 PageSize { get; set; }

        /// <summary>
        /// The page number requested by the user. If not provided 1 is assumed by default.
        /// </summary>
        public Int32 PageNumber { get; set; }

        /// <summary>
        /// Defines the type of sorting to be applied on the results. 
        /// The page slice is cut of the sorted results only.
        /// </summary>
        public Int32 SortBy { get; set; }

        /// <summary>
        /// Defines the order of sorting, 1 for Ascending, 2 for Descending, else default ordering based on the SortBy value
        /// </summary>
        public Int32 SortOrder { get; set; }

        /// <summary>
        /// This is internal field to record the actual unsanitized query which was provided by the user
        /// </summary>
        internal string RawQuery { get; set; }

        /// <summary>
        /// These define the metadata that will be returned along with the query result.
        /// </summary>
        public ExtensionQueryResultMetadataFlags MetadataFlags { get; set; }

        /// <summary>
        /// Product type for which the query extensions is being called.
        /// This is used for calculating the weighted average.
        /// </summary>
        public string Product { get; set; }

        /// <summary>
        /// Way to pass feature flags for selective functionality
        /// </summary>
        internal SearchFeatureFlags FeatureFlags { get; set; }
    }

    [Flags]
    public enum SearchOverrideFlags
    {
        None = 0x0,
        DoNotTranslateCategoryFilter = 0x1,
        // IncludePrivate = 0x2,
        // UseDbForSearch = 0x4
    }

    internal class QueryMetadataConstants
    {
        public static readonly string Categories = "Categories";
        public static readonly string TotalCount = "TotalCount";
        public static readonly string ResultCount = "ResultCount";
        public static readonly string ResultSetCategories = "ResultSetCategories";
        public static readonly string ResultSetProjectTypes = "ResultSetProjectTypes";
        public static readonly string TargetPlatforms = "TargetPlatforms";
    }
}
