// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;
using SearchScorer.Common;

namespace SearchScorer.Common
{
    public class PublishedExtensionConverter : JsonConverter<PublishedExtension>
    {
        public override PublishedExtension Read(
            ref Utf8JsonReader reader,
            Type typeToConvert,
            JsonSerializerOptions options)
        {
            throw new NotImplementedException();
        }

        public override void Write(Utf8JsonWriter writer,
            PublishedExtension publishedExtension,
            JsonSerializerOptions options)
        {
            writer.WriteStartObject();

            writer.WriteStartObject("publisher");
            writer.WriteString("publisherId", publishedExtension.Publisher.PublisherId);
            writer.WriteString("publisherName", publishedExtension.Publisher.PublisherName);
            writer.WriteString("displayName", publishedExtension.Publisher.DisplayName);
            writer.WriteString("flags", publishedExtension.Publisher.Flags.ToString().ConvertFlagsToString());
            writer.WriteString("domain", publishedExtension.Publisher.Domain);
            writer.WriteBoolean("isDomainVerified", publishedExtension.Publisher.IsDomainVerified);
            writer.WriteEndObject();

            writer.WriteString("extensionId", publishedExtension.ExtensionId);
            writer.WriteString("extensionName", publishedExtension.ExtensionName);
            writer.WriteString("displayName", publishedExtension.DisplayName);
            writer.WriteString("flags", publishedExtension.Flags.ToString().ConvertFlagsToString());
            writer.WriteString("lastUpdated", publishedExtension.LastUpdated);
            writer.WriteString("publishedDate", publishedExtension.PublishedDate);
            if (publishedExtension.ReleaseDate != null)
            {
                writer.WriteString("releaseDate", publishedExtension.ReleaseDate);
            }

            if (publishedExtension.ShortDescription != null)
            {
                writer.WriteString("shortDescription", publishedExtension.ShortDescription);
            }

            if (publishedExtension.LongDescription != null)
            {
                writer.WriteString("longDescription", publishedExtension.LongDescription);
            }

            if (publishedExtension.Versions != null)
            {
                writer.WriteStartArray("versions");
                foreach (var version in publishedExtension.Versions)
                {
                    ExtensionVersionConverter evc = new ExtensionVersionConverter();
                    evc.Write(writer, version, options);
                }

                writer.WriteEndArray();
            }

            if (publishedExtension.Categories != null)
            {
                writer.WriteStartArray("categories");
                foreach (var category in publishedExtension.Categories)
                {
                    writer.WriteStringValue(category);
                }

                writer.WriteEndArray();
            }

            if (publishedExtension.Tags != null)
            {
                writer.WriteStartArray("tags");
                foreach (var tag in publishedExtension.Tags)
                {
                    writer.WriteStringValue(tag);
                }

                writer.WriteEndArray();
            }

            if (publishedExtension.Statistics != null)
            {
                writer.WriteStartArray("statistics");
                foreach (var statistics in publishedExtension.Statistics)
                {
                    writer.WriteStartObject();
                    writer.WriteString("statisticName", statistics.StatisticName);
                    writer.WriteNumber("value", statistics.Value);
                    writer.WriteEndObject();
                }
                writer.WriteEndArray();
            }

            if (publishedExtension.InstallationTargets != null)
            {
                writer.WriteStartArray("installationTargets");
                foreach (var installationTarget in publishedExtension.InstallationTargets)
                {
                    writer.WriteStartObject();
                    writer.WriteString("target", installationTarget.Target);
                    writer.WriteString("targetVersion", installationTarget.TargetVersion);
                    writer.WriteEndObject();
                }
                writer.WriteEndArray();
            }

            writer.WriteNumber("deploymentType", (int)publishedExtension.DeploymentType);
            writer.WriteEndObject();
        }
    }
}