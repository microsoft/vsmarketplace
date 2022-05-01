// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;
using System.Text.Json.Serialization;

namespace SearchScorer.Common
{
    [JsonConverter(typeof(ExtensionFileConverter))]
    public class ExtensionFile
    {
        internal Guid ReferenceId { get; set; }

        public String AssetType { get; set; }

        public String Language { get; set; }

        public String Source { get; set; }

        public String Version { get; set; }

        public String ContentType { get; set; }

        public Int32 FileId { get; set; }

        public String ShortDescription { get; set; }

        public Boolean IsDefault { get; set; }

        public Boolean IsPublic { get; set; }

        internal ExtensionFile ShallowCopy()
        {
            return (ExtensionFile)this.MemberwiseClone();
        }
    }
}
