// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;

namespace SearchScorer.Common
{
    public class CdnUriPathBuilder
    {
        public string PublisherName { get; set; }
        public string ExtensionName { get; set; }
        public string ExtensionVersion { get; set; }
        public string AssetRoot { get; set; }

        public const string CdnUrlFormat = "{0}/{1}/{2}/{3}";

        public static string GetExtensionAssetUploadPath(string publisherName,
            string extensionName,
            string extensionVersion,
            string assetRoot)
        {
            return string.Format(CdnUrlFormat,
                                Uri.EscapeDataString(publisherName.ToLowerInvariant()),
                                Uri.EscapeDataString(extensionName.ToLowerInvariant()),
                                Uri.EscapeDataString(extensionVersion.ToLowerInvariant()),
                                assetRoot != null ? Uri.EscapeDataString(assetRoot) : string.Empty);
        }
    }
}