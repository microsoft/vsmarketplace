// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;
using Microsoft.Azure.Search;

namespace SearchScorer.Common
{
    public class AzureIndexDocument
    {
        [System.ComponentModel.DataAnnotations.Key]
        [IsSearchable, IsFilterable]
        public string ExtensionId { get; set; }

        [IsSearchable, IsSortable, IndexAnalyzer("DefaultIndexAnalyzer"), SearchAnalyzer("SearchTermAnalyzer")]
        public string ExtensionName { get; set; }

        [IsSearchable, IsFilterable, IsSortable, IndexAnalyzer("DefaultIndexAnalyzer"), SearchAnalyzer("SearchTermAnalyzer")]
        public string ExtensionDisplayName { get; set; }

        [IsSearchable, IsFilterable, IsSortable, IndexAnalyzer("PrefixAnalyzer"), SearchAnalyzer("SearchTermAnalyzer")]
        public string ExtensionDisplayNameForPrefixMatch { get; set; }

        [IsSearchable, IndexAnalyzer("DefaultIndexAnalyzer"), SearchAnalyzer("SearchTermAnalyzer")]
        public string ShortDescription { get; set; }

        [IsSearchable, IndexAnalyzer("PrefixAnalyzer"), SearchAnalyzer("SearchTermAnalyzer")]
        public string ShortDescriptionForPrefixMatch { get; set; }

        public string PublisherName { get; set; }

        [IsSearchable, IsFilterable, IsSortable, IndexAnalyzer("DefaultIndexAnalyzer"), SearchAnalyzer("SearchTermAnalyzer")]
        public string PublisherDisplayName { get; set; }

        [IsSearchable, IsFilterable, IsSortable, IndexAnalyzer("PrefixAnalyzer"), SearchAnalyzer("SearchTermAnalyzer")]
        public string PublisherDisplayNameForPrefixMatch { get; set; }

        [IsSearchable, IsRetrievable(false), Analyzer("KeywordIndexAnalyzer")]
        public string PublisherDisplayNameForExactMatch { get; set; }

        [IsSearchable, IsRetrievable(false), Analyzer("KeywordIndexAnalyzer")]
        public string ExtensionFullyQualifiedNameForExactMatch { get; set; }

        [IsSearchable, IsRetrievable(false), Analyzer("KeywordIndexAnalyzer")]
        public string ExtensionNameForExactMatch { get; set; }

        [IsSearchable, IsRetrievable(false), Analyzer("KeywordIndexAnalyzer")]
        public string PublisherNameForExactMatch { get; set; }

        [IsSearchable, IsRetrievable(false), Analyzer("KeywordIndexAnalyzer")]
        public string ExtensionDisplayNameForExactMatch { get; set; }

        [IsFilterable]
        public List<String> ExtensionFlags { get; set; }

        [IsFilterable, IsRetrievable(false)]
        public List<String> PublisherFlags { get; set; }

        public string Publisher { get; set; }

        [IsFilterable]
        public Boolean? IsDomainVerified { get; set; }

        [IsSortable]
        public DateTime? LastUpdated { get; set; }

        public DateTime? PublishedDate { get; set; }

        [IsSortable]
        public DateTime? ReleasedDate { get; set; }

        public List<String> Tags { get; set; }

        [IsRetrievable(false), IsSearchable, IsFilterable, IndexAnalyzer("PrefixAnalyzer"), SearchAnalyzer("SearchTermAnalyzer")]
        public List<String> SearchableTags { get; set; }

        [IsFilterable, IsFacetable]
        public List<String> Categories { get; set; }

        [IsFilterable, IsFacetable, IsRetrievable(false)]
        public List<string> TargetPlatforms { get; set; }

        /// <summary>
        /// The total number of installs, including updates.
        /// This is deprecated, use InstallCount for sorting.
        /// </summary>
        [IsSortable, IsFilterable]
        public double DownloadCount { get; set; }

        /// <summary>
        /// The number of unique installations, not including updates.
        /// Used to support to sort by InstallCount.
        /// </summary>
        [IsSortable, IsFilterable]
        public double? InstallCount { get; set; }

        [IsSortable, IsFilterable, IsRetrievable(false)]
        public double WeightedRating { get; set; }

        [IsSortable]
        public double TrendingScore { get; set; }

        [IsFilterable, IsRetrievable(false)]
        public List<string> InstallationTargetList { get; set; }

        [IsFilterable, IsRetrievable(false)]
        public List<string> SearchableMetadata { get; set; }

        public string Metadata { get; set; }

        public string DeploymentType { get; set; }

        public string ValidatedVersions { get; set; }

        public string AllVersions { get; set; }

        public string Statistics { get; set; }

        public string SharedWith { get; set; }

        public string InstallationTargets { get; set; }

        [IsFilterable, IsRetrievable(false)]
        public List<string> EnterpriseSharedWithIds { get; set; }

        [IsFilterable, IsRetrievable(false)]
        public List<string> OrgSharedWithIds { get; set; }

        [IsFilterable]
        public List<string> Lcids { get; set; }

        // This field is currently used only for VS index.
        // However for sake of simplicity, keeping this field for all index types.
        // In case we see in future that the number of independent values are increasing,
        // we can split accordingly.
        [IsFilterable, IsFacetable, IsRetrievable(false)]
        public string ProjectType { get; set; }

        public AzureIndexDocument ShallowCopy()
        {
            return (AzureIndexDocument)this.MemberwiseClone();
        }
    }

    public class ServerExtensionFile : ExtensionFile
    {
        public Int32 SerializableFileId { get; set; }
    }

    /// <summary>
    /// We are creating a new type here, FileId was not serializable in ExtensionFile
    /// </summary>
    [JsonConverter(typeof(ServerExtensionVersionConverter))]
    public class ServerExtensionVersion
    {
        internal Guid ExtensionId { get; set; }

        public String Version { get; set; }

        public String TargetPlatform { get; set; }

        public ExtensionVersionFlags Flags { get; set; }

        public DateTime LastUpdated { get; set; }

        public String VersionDescription { get; set; }

        public String ValidationResultMessage { get; set; }

        public List<ServerExtensionFile> Files { get; set; }

        public List<KeyValuePair<String, String>> Properties { get; set; }

        public List<ExtensionBadge> Badges { get; set; }

        public String AssetUri { get; set; }

        public String FallbackAssetUri { get; set; }
        internal string CdnDirectory { get; set; }
        internal bool IsCdnEnabled { get; set; }
        public ServerExtensionVersion ShallowCopy()
        {
            return (ServerExtensionVersion)this.MemberwiseClone();
        }
        public string GetCdnDirectory()
        {
            return CdnDirectory;
        }
    }
}
