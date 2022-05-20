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
    public class ServerExtensionVersionConverter : JsonConverter<ServerExtensionVersion>
    {
        public override ServerExtensionVersion Read(
            ref Utf8JsonReader reader,
            Type typeToConvert,
            JsonSerializerOptions options)
        {
            if (reader.TokenType != JsonTokenType.StartObject)
            {
                throw new JsonException();
            }

            var serverExtensionVersion = new ServerExtensionVersion();

            while (reader.Read())
            {
                if (reader.TokenType == JsonTokenType.EndObject)
                {
                    return serverExtensionVersion;
                }

                if (reader.TokenType == JsonTokenType.PropertyName)
                {
                    string propertyName = reader.GetString().ToLowerInvariant();
                    reader.Read();
                    switch (propertyName)
                    {
                        case "version":
                            serverExtensionVersion.Version = reader.GetString();
                            break;
                        case "flags":
                            string extensionVersionFlags = reader.GetString();
                            ExtensionVersionFlags flags = default(ExtensionVersionFlags);
                            var versionFlags = extensionVersionFlags.Split(",")
                                .Select(x => x.Trim())
                                .ToList();

                            foreach (var flag in versionFlags)
                            {
                                flags = flags | (ExtensionVersionFlags)Enum.Parse(typeof(ExtensionVersionFlags), flag, true);
                            }

                            serverExtensionVersion.Flags = flags;
                            break;
                        case "lastupdated":
                            serverExtensionVersion.LastUpdated = reader.GetDateTime();
                            break;
                        case "versiondescription":
                            serverExtensionVersion.VersionDescription = reader.GetString();
                            break;
                        case "validationresultmessage":
                            serverExtensionVersion.ValidationResultMessage = reader.GetString();
                            break;
                        case "files":
                            string files;
                            using (var jsonDoc = JsonDocument.ParseValue(ref reader))
                            {
                                files = jsonDoc.RootElement.GetRawText();
                            }

                            serverExtensionVersion.Files = JsonSerializer.Deserialize<List<ServerExtensionFile>>(files);
                            break;
                        case "properties":
                            string properties;
                            using (var jsonDoc = JsonDocument.ParseValue(ref reader))
                            {
                                properties = jsonDoc.RootElement.GetRawText();
                            }

                            serverExtensionVersion.Properties = JsonSerializer.Deserialize<List<KeyValuePair<String, String>>>(properties);
                            break;
                        case "badges":
                            string badges;
                            using (var jsonDoc = JsonDocument.ParseValue(ref reader))
                            {
                                badges = jsonDoc.RootElement.GetRawText();
                            }
                            serverExtensionVersion.Badges = JsonSerializer.Deserialize<List<ExtensionBadge>>(badges);
                            break;
                        case "asseturi":
                            serverExtensionVersion.AssetUri = reader.GetString();
                            break;
                        case "fallbackasseturi":
                            serverExtensionVersion.FallbackAssetUri = reader.GetString();
                            break;
                        case "targetplatform":
                            serverExtensionVersion.TargetPlatform = reader.GetString();
                            break;
                    }
                }
            }

            throw new JsonException();
        }

        public override void Write(Utf8JsonWriter writer, ServerExtensionVersion value, JsonSerializerOptions options)
        {
            throw new NotImplementedException();
        }
    }
}
