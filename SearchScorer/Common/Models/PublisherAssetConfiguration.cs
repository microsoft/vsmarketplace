// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;

namespace SearchScorer.Common
{
    public class PublisherAssetConfiguration
    {
        public String Host { get; set; }
        public String CdnHost { get; set; }
        public String ChinaCdnHost { get; set; }
        public String VirtualPath { get; set; } = "/";
    }
}