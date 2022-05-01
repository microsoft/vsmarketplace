// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;
using System.Text.Json.Serialization;

namespace SearchScorer.Common
{
    [JsonConverter(typeof(ExtensionBadgeConverter))]
    public class ExtensionBadge
    {
        public String Link { get; set; }

        public String ImgUri { get; set; }

        public String Description { get; set; }
    }

    public class InstallationTarget
    {
        public String Target { get; set; }

        public String TargetVersion { get; set; }

        public Version MinVersion { get; set; }

        public Version MaxVersion { get; set; }

        public bool MinInclusive { get; set; }

        public bool MaxInclusive { get; set; }
    }
}
