// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using SearchScorer.Common;

namespace SearchScorer.Common
{
    public class ExtensionVersionConverter : JsonConverter<ExtensionVersion>
    {
        public override ExtensionVersion Read(
            ref Utf8JsonReader reader,
            Type typeToConvert,
            JsonSerializerOptions options)
        {
            if (reader.TokenType != JsonTokenType.StartObject)
            {
                throw new JsonException();
            }

            var extensionVersion = new ExtensionVersion();

            while (reader.Read())
            {
                if (reader.TokenType == JsonTokenType.EndObject)
                {
                    return extensionVersion;
                }

                if (reader.TokenType == JsonTokenType.PropertyName)
                {
                    string propertyName = reader.GetString().ToLowerInvariant();
                    reader.Read();
                    switch (propertyName)
                    {
                        case "version":
                            extensionVersion.Version = reader.GetString();
                            break;
                        case "flags":
                            var extensionVersionFlags = reader.GetString();
                            var versionFlags = extensionVersionFlags.Split(",")
                                .Select(x => x.Trim())
                                .ToList();
                            ExtensionVersionFlags flags = default(ExtensionVersionFlags);
                            foreach (var flag in versionFlags)
                            {
                                flags = flags | (ExtensionVersionFlags)Enum.Parse(typeof(ExtensionVersionFlags), flag, true);
                            }
                            extensionVersion.Flags = flags;
                            break;
                        case "lastupdated":
                            extensionVersion.LastUpdated = reader.GetDateTime();
                            break;
                        case "versiondescription":
                            extensionVersion.VersionDescription = reader.GetString();
                            break;
                        case "validationresultmessage":
                            extensionVersion.ValidationResultMessage = reader.GetString();
                            break;
                        case "files":
                            string files;
                            using (var jsonDoc = JsonDocument.ParseValue(ref reader))
                            {
                                files = jsonDoc.RootElement.GetRawText();
                            }

                            extensionVersion.Files = JsonSerializer.Deserialize<List<ExtensionFile>>(files);
                            break;
                        case "properties":
                            string properties;
                            using (var jsonDoc = JsonDocument.ParseValue(ref reader))
                            {
                                properties = jsonDoc.RootElement.GetRawText();
                            }
                            extensionVersion.Properties = JsonSerializer.Deserialize<List<KeyValuePair<String, String>>>(properties);
                            break;
                        case "badges":
                            string badges;
                            using (var jsonDoc = JsonDocument.ParseValue(ref reader))
                            {
                                badges = jsonDoc.RootElement.GetRawText();
                            }
                            extensionVersion.Badges = JsonSerializer.Deserialize<List<ExtensionBadge>>(badges);
                            break;
                        case "asseturi":
                            extensionVersion.AssetUri = reader.GetString();
                            break;
                        case "fallbackasseturi":
                            extensionVersion.FallbackAssetUri = reader.GetString();
                            break;
                        case "cdndirectory":
                            extensionVersion.CdnDirectory = reader.GetString();
                            break;
                        case "iscdnenabled":
                            extensionVersion.IsCdnEnabled = reader.GetBoolean();
                            break;
                        case "targetplatform":
                            extensionVersion.TargetPlatform = reader.GetString();
                            break;
                    }
                }
            }

            throw new JsonException();
        }

        public override void Write(Utf8JsonWriter writer,
            ExtensionVersion extensionVersion,
            JsonSerializerOptions options)
        {
            writer.WriteStartObject();
            writer.WriteString("version", extensionVersion.Version);
            if (extensionVersion.TargetPlatform != null)
            {
                writer.WriteString("targetPlatform", extensionVersion.TargetPlatform);
            }

            writer.WriteString("flags", extensionVersion.Flags.ToString().ConvertFlagsToString());
            writer.WriteString("lastUpdated", extensionVersion.LastUpdated);
            if (extensionVersion.VersionDescription != null)
            {
                writer.WriteString("versionDescription", extensionVersion.VersionDescription);
            }

            if (extensionVersion.ValidationResultMessage != null)
            {
                writer.WriteString("validationResultMessage", extensionVersion.ValidationResultMessage);
            }

            if (extensionVersion.Files != null)
            {
                writer.WriteStartArray("files");
                ExtensionFileConverter extensionFileConverter = new ExtensionFileConverter();
                foreach (var file in extensionVersion.Files)
                {
                    extensionFileConverter.Write(writer, file, options);
                }

                writer.WriteEndArray();
            }

            if (extensionVersion.Properties != null)
            {
                writer.WriteStartArray("properties");
                foreach (var property in extensionVersion.Properties)
                {
                    writer.WriteStartObject();
                    writer.WriteString("key", property.Key);
                    writer.WriteString("value", property.Value);
                    writer.WriteEndObject();
                }

                writer.WriteEndArray();
            }

            if (extensionVersion.Badges != null)
            {
                writer.WriteStartArray("badges");
                ExtensionBadgeConverter extensionBadgeConverter = new ExtensionBadgeConverter();
                foreach (var file in extensionVersion.Badges)
                {
                    extensionBadgeConverter.Write(writer, file, options);
                }

                writer.WriteEndArray();
            }

            if (extensionVersion.AssetUri != null)
            {
                writer.WriteString("assetUri", extensionVersion.AssetUri);
            }

            if (extensionVersion.FallbackAssetUri != null)
            {
                writer.WriteString("fallbackAssetUri", extensionVersion.FallbackAssetUri);
            }

            writer.WriteEndObject();
        }
    }
}
