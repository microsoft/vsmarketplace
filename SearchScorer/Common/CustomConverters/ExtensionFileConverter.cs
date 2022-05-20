// -----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// -----------------------------------------------------------------------------

using System;
using System.Text.Json;
using System.Text.Json.Serialization;
using SearchScorer.Common;

namespace SearchScorer.Common
{
    public class ExtensionFileConverter : JsonConverter<ExtensionFile>
    {
        public override ExtensionFile Read(
            ref Utf8JsonReader reader,
            Type typeToConvert,
            JsonSerializerOptions options)
        {
            if (reader.TokenType != JsonTokenType.StartObject)
            {
                throw new JsonException();
            }

            var extensionFile = new ExtensionFile();

            while (reader.Read())
            {
                if (reader.TokenType == JsonTokenType.EndObject)
                {
                    return extensionFile;
                }

                if (reader.TokenType == JsonTokenType.PropertyName)
                {
                    string propertyName = reader.GetString().ToLowerInvariant();
                    reader.Read();
                    switch (propertyName)
                    {
                        case "assettype":
                            extensionFile.AssetType = reader.GetString();
                            break;
                        case "language":
                            extensionFile.Language = reader.GetString();
                            break;
                        case "source":
                            extensionFile.Source = reader.GetString();
                            break;
                        case "version":
                            extensionFile.Version = reader.GetString();
                            break;
                        case "contenttype":
                            extensionFile.ContentType = reader.GetString();
                            break;
                        case "fileid":
                            extensionFile.FileId = reader.GetInt32();
                            break;
                        case "shortdescription":
                            extensionFile.ShortDescription = reader.GetString();
                            break;
                        case "isdefault":
                            extensionFile.IsDefault = reader.GetBoolean();
                            break;
                        case "ispublic":
                            extensionFile.IsPublic = reader.GetBoolean();
                            break;
                    }
                }
            }

            throw new JsonException();
        }

        public override void Write(Utf8JsonWriter writer,
            ExtensionFile extensionFile,
            JsonSerializerOptions options)
        {
            writer.WriteStartObject();

            writer.WriteString("assetType", extensionFile.AssetType);
            if (extensionFile.Language != null)
            {
                writer.WriteString("language", extensionFile.Language);
            }

            if (extensionFile.Source != null)
            {
                writer.WriteString("source", extensionFile.Source);
            }

            writer.WriteEndObject();
        }
    }
}