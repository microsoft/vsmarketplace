// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Runtime.Serialization;

namespace SearchScorer.Common
{
    public static class WellKnownTags
    {
        public const String Tag_BuiltIn = "$BuiltIn";
        public const String Tag_Featured = "$Featured";
        public const String Tag_FromMS = "$FromMS";
        public const String Tag_TopFree = "$TopFree";
        public const String Tag_TopPaid = "$TopPaid";
        public const String Tag_TopRated = "$TopRated";
    }

    /// <summary>
    /// Type of extension filters that are supported in the queries.
    /// </summary>
    [DataContract]
    public enum ExtensionQueryFilterType
    {
        /// <summary>
        /// The values are used as tags. All tags are treated as "OR" conditions 
        /// with each other. There may be some value put on the number of matched
        /// tags from the query.
        /// </summary>
        [DataMember]
        Tag = 1,

        /// <summary>
        /// The Values are an ExtensionName or fragment that is used to match other 
        /// extension names.
        /// </summary>
        [DataMember]
        DisplayName = 2,

        /// <summary>
        /// The Filter is one or more tokens that define what scope to return
        /// private extensions for.
        /// </summary>
        [DataMember]
        Private = 3,

        /// <summary>
        /// Retrieve a set of extensions based on their id's. The values should be
        /// the extension id's encoded as strings.
        /// </summary>
        [DataMember]
        Id = 4,

        /// <summary>
        /// The category is unlike other filters. It is AND'd with the other filters
        /// instead of being a separate query.
        /// </summary>
        [DataMember]
        Category = 5,

        /// <summary>
        /// Certain contribution types may be indexed to allow for query by type.
        /// User defined types can't be indexed at the moment.
        /// </summary>
        [DataMember]
        ContributionType = 6,

        /// <summary>
        /// Retrieve an set extension based on the name based identifier. This
        /// differs from the internal id (which is being deprecated).
        /// </summary>
        [DataMember]
        Name = 7,

        /// <summary>
        /// The InstallationTarget for an extension defines the target consumer
        /// for the extension. This may be something like VS, VSOnline, or VSCode
        /// </summary>
        [DataMember]
        InstallationTarget = 8,

        /// <summary>
        /// Query for featured extensions, no value is allowed when using the 
        /// query type.
        /// </summary>
        [DataMember]
        Featured = 9,

        /// <summary>
        /// The SearchText provided by the user to search for extensions
        /// </summary>
        [DataMember]
        SearchText = 10,

        /// <summary>
        /// Query for extensions that are featured in their own category, The filterValue
        /// for this is name of category of extensions.
        /// </summary>
        [DataMember]
        FeaturedInCategory = 11,

        /// <summary>
        /// When retrieving extensions from a query, exclude the extensions which are 
        /// having the given flags. The value specified for this filter should be a string
        /// representing the integer values of the flags to be excluded. In case of multiple flags 
        /// to be specified, a logical OR of the interger values should be given as value for this filter
        /// This should be at most one filter of this type.
        /// This only acts as a restrictive filter after.
        /// In case of having a particular flag in both IncludeWithFlags and ExcludeWithFlags, 
        /// excludeFlags will remove the included extensions giving empty result for that flag.
        /// </summary>
        [DataMember]
        ExcludeWithFlags = 12,

        /// <summary>
        /// When retrieving extensions from a query, include the extensions which are 
        /// having the given flags. The value specified for this filter should be a string
        /// representing the integer values of the flags to be included. In case of multiple flags 
        /// to be specified, a logical OR of the integer values should be given as value for this filter
        /// This should be at most one filter of this type. 
        /// This only acts as a restrictive filter after.
        /// In case of having a particular flag in both IncludeWithFlags and ExcludeWithFlags, 
        /// excludeFlags will remove the included extensions giving empty result for that flag.
        /// In case of multiple flags given in IncludeWithFlags in ORed fashion, extensions having any of the given flags will be included.
        /// </summary>
        [DataMember]
        IncludeWithFlags = 13,

        /// <summary>
        /// Filter the extensions based on the LCID values applicable. Any extensions which are not having any LCID values
        /// will also be filtered. This is currently only supported for VS extensions.
        /// </summary>
        [DataMember]
        Lcid = 14,

        /// <summary>
        /// Filter to provide the version of the installation target. This filter will be used along with InstallationTarget filter.
        /// The value should be a valid version string. Currently supported only if search text is provided.
        /// </summary>
        [DataMember]
        InstallationTargetVersion = 15,

        /// <summary>
        /// Filter type for specifying a range of installation target version. The filter will be used along with InstallationTarget filter.
        /// The value should be a pair of well formed version values separated by hyphen(-). Currently supported only if search text is provided.
        /// </summary>
        [DataMember]
        InstallationTargetVersionRange = 16,

        /// <summary>
        /// Filter type for specifying metadata key and value to be used for filtering.
        /// </summary>
        [DataMember]
        VsixMetadata = 17,

        /// <summary>
        /// Filter to get extensions published by a publisher having supplied internal name
        /// </summary>
        [DataMember]
        PublisherName = 18,

        /// <summary>
        /// Filter to get extensions published by all publishers having supplied display name
        /// </summary>
        [DataMember]
        PublisherDisplayName = 19,

        /// <summary>
        /// When retrieving extensions from a query, include the extensions which have a publisher 
        /// having the given flags. The value specified for this filter should be a string
        /// representing the integer values of the flags to be included. In case of multiple flags 
        /// to be specified, a logical OR of the integer values should be given as value for this filter
        /// There should be at most one filter of this type. 
        /// This only acts as a restrictive filter after.
        /// In case of multiple flags given in IncludeWithFlags in ORed fashion, extensions having any of the given flags will be included.
        /// </summary>
        [DataMember]
        IncludeWithPublisherFlags = 20,

        /// <summary>
        /// Filter to get extensions shared with particular organization
        /// </summary>
        [DataMember]
        [Obsolete]
        OrganizationSharedWith = 21,

        /// <summary>
        /// Filter to get VS IDE extensions by Product Architecture
        /// </summary>
        [DataMember]
        ProductArchitecture = 22,

        /// <summary>
        /// Filter to get VS Code extensions by target platform.
        /// </summary>
        [DataMember]
        TargetPlatform = 23
    }

    /// <summary>
    /// Defines the sort order that can be defined for Extensions query
    /// </summary>
    [DataContract]
    public enum SortByType
    {
        /// <summary>
        /// The results will be sorted by relevance in case search query is given, if no search query resutls will be provided as is
        /// </summary>
        [DataMember]
        Relevance = 0,

        /// <summary>
        /// The results will be sorted as per Last Updated date of the extensions with recently updated at the top
        /// </summary>
        [DataMember]
        LastUpdatedDate = 1,

        /// <summary>
        /// Results will be sorted Alphabetically as per the title of the extension
        /// </summary>
        [DataMember]
        Title = 2,

        /// <summary>
        /// Results will be sorted Alphabetically as per Publisher title
        /// </summary>
        [DataMember]
        Publisher = 3,

        /// <summary>
        /// Results will be sorted by Install Count
        /// </summary>
        [DataMember]
        InstallCount = 4,

        /// <summary>
        /// The results will be sorted as per Published date of the extensions
        /// </summary>
        [DataMember]
        PublishedDate = 5,

        /// <summary>
        /// The results will be sorted as per Average ratings of the extensions
        /// </summary>
        [DataMember]
        AverageRating = 6,

        /// <summary>
        /// The results will be sorted as per Trending Daily Score of the extensions
        /// </summary>
        [DataMember]
        TrendingDaily = 7,

        /// <summary>
        /// The results will be sorted as per Trending weekly Score of the extensions
        /// </summary>
        [DataMember]
        TrendingWeekly = 8,

        /// <summary>
        /// The results will be sorted as per Trending monthly Score of the extensions
        /// </summary>
        [DataMember]
        TrendingMonthly = 9,

        /// <summary>
        /// The results will be sorted as per ReleaseDate of the extensions (date on which the extension first went public)
        /// </summary>
        [DataMember]
        ReleaseDate = 10,

        /// <summary>
        /// The results will be sorted as per Author defined in the VSix/Metadata. If not defined, publisher name is used
        /// This is specifically needed by VS IDE, other (new and old) clients are not encouraged to use this
        /// </summary>
        [DataMember]
        Author = 11,

        /// <summary>
        /// The results will be sorted as per Weighted Rating of the extension.
        /// </summary>
        [DataMember]
        WeightedRating = 12
    }

    /// <summary>
    /// Defines the sort order that can be defined for Extensions query
    /// </summary>
    [DataContract]
    public enum SortOrderType
    {
        /// <summary>
        /// Results will be sorted in the default order as per the sorting type defined. 
        /// The default varies for each type, e.g. for Relevance, default is Descending, for Title default is Ascending etc.
        /// </summary>
        [DataMember]
        Default = 0,

        /// <summary>
        /// The results will be sorted in Ascending order
        /// </summary>
        [DataMember]
        Ascending = 1,

        /// <summary>
        /// The results will be sorted in Descending order
        /// </summary>
        [DataMember]
        Descending = 2
    }

    /// <summary>
    /// An ExtensionQuery is used to search the gallery for a set of 
    /// extensions that match one of many filter values.
    /// </summary>
    public class ExtensionQuery
    {
        /// <summary>
        /// Each filter is a unique query and will have matching set of extensions
        /// returned from the request. Each result will have the same index in the
        /// resulting array that the filter had in the incoming query.
        /// </summary>
        public List<QueryFilter> Filters { get; set; }

        /// <summary>
        /// The Flags are used to determine which set of information the caller would
        /// like returned for the matched extensions.
        /// </summary>
        public ExtensionQueryFlags Flags { get; set; }

        /// <summary>
        /// When retrieving extensions with a query; frequently the caller only
        /// needs a small subset of the assets. The caller may specify a list
        /// of asset types that should be returned if the extension contains it.
        /// All other assets will not be returned.
        /// </summary>
        public List<String> AssetTypes { get; set; }

        /// <summary>
        /// The flags are used to determine what metadata is to be sent along with the
        /// query response. This works only for SearchExtensions query and not for QueryExtensions.
        /// </summary>
        // internal ExtensionQueryResultMetadataFlags? MetadataFlags { get; set; }
        public ExtensionQueryResultMetadataFlags? MetadataFlags { get; set; }
    }

    /// <summary>
    /// This is the set of extensions that matched a supplied query through the
    /// filters given.
    /// </summary>
    public class ExtensionQueryResult
    {
        /// <summary>
        /// For each filter supplied in the query, a filter result will be returned
        /// in the query result.
        /// </summary>
        public List<ExtensionFilterResult> Results { get; set; }
    }

    /// <summary>
    /// The FilterResult is the set of extensions that matched a particular 
    /// query filter.
    /// </summary>
    public class ExtensionFilterResult
    {
        /// <summary>
        /// This is the set of applications that matched the query filter
        /// supplied.
        /// </summary>
        public List<PublishedExtension> Extensions { get; set; }

        /// <summary>
        /// The PagingToken is returned from a request when more records exist
        /// that match the result than were requested or could be returned. A
        /// follow-up query with this paging token can be used to retrieve 
        /// more results.
        /// </summary>
        public String PagingToken { get; set; }

        /// <summary>
        /// This is the additional optional metadata for the given result.
        /// E.g. Total count of results which is useful in case of paged results
        /// </summary>
        public List<ExtensionFilterResultMetadata> ResultMetadata { get; set; }
    }

    /// <summary>
    /// ExtensionFilterResultMetadata is one set of metadata for the result e.g. Total count.
    /// There can be multiple metadata items for one metadata.
    /// </summary>
    public class ExtensionFilterResultMetadata
    {
        /// <summary>
        /// Defines the category of metadata items
        /// </summary>
        public String MetadataType { get; set; }

        /// <summary>
        /// The metadata items for the category
        /// </summary>
        public List<MetadataItem> MetadataItems { get; set; }
    }

    /// <summary>
    /// MetadataItem is one value of metadata under a given category of metadata
    /// </summary>
    public class MetadataItem
    {
        /// <summary>
        /// The name of the metadata item
        /// </summary>
        public String Name { get; set; }

        /// <summary>
        /// The count of the metadata item
        /// </summary>
        public int Count { get; set; }
    }

    /// <summary>
    /// Parameters which can be given as part of search query
    /// All parameters restrict the result set by default.
    /// Multiple params of same type means OR for the given values
    /// </summary>
    public static class EqlParams
    {
        /// <summary>
        /// Name parameter to restrict the results matching extension name only to the given value following the parameter
        /// If nothing else is given all extension names matching the given value are returned.
        /// Multiple params of name within same query means extensions matching any one of the given values
        /// </summary>
        public const string Name = "name:";

        /// <summary>
        /// Publisher parameter to restrict the results matching publisher name only to the given value following the parameter
        /// If nothing else is given all extension by publishers whose name is matching the given value are returned.
        /// Multiple params of publisher within same query means extensions' publisher name matching any one of the given values
        /// </summary>
        public const string Publisher = "publisher:";

        /// <summary>
        /// Tag parameter to restrict the results matching tag name only to the given value following the parameter
        /// If nothing else is given all extension with tag name matching the given value are returned.
        /// Multiple params of tag within same query means extensions' having tag name matching any one of the given values
        /// </summary>
        public const string Tag = "tag:";

        /// <summary>
        /// Category parameter to restrict the results matching "Exact" category name only to the given value following the parameter
        /// If nothing else is given all extension having category name matching the given value are returned.
        /// Multiple params of category within same query means extensions' belonging to any one of the given values
        /// </summary>
        public const string Category = "category:";

        /// <summary>
        /// Installation target parameter to restrict the results matching "Exact" installation target name only to the given value
        /// following the parameter.
        /// If nothing else is given all extension having installation target matching the given value are returned.
        /// Multiple params of installation target within same query means extensions' belonging to any one of the given values
        /// The installation targets should be encloseed in double quotes as it may contain '.'s and search query will not interpret
        /// the dots without double quotes.
        /// </summary>
        public const string Target = "target:";
    }
}
